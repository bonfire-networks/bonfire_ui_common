defmodule Bonfire.UI.Common.CacheControlPlugTest do
  @moduledoc """
  Tests that CacheControlPlug sets correct Cache-Control headers via the
  `:cacheable` pipeline, using the gen_avatar endpoint as a real-world example.

  Also verifies that no Set-Cookie header is emitted — the `:cacheable` pipeline
  deliberately excludes session setup, so cookies can never leak into a cached
  response.

  The purge tests complete the loop: activate the StaticGenerator purge adapter
  via Process.put so that MaybeStaticGeneratorPlug writes a static file for each
  request, then assert the file is gone after bust_urls / bust_tags.
  """

  use Bonfire.UI.Common.ConnCase, async: true

  alias Bonfire.Common.Cache
  alias Bonfire.UI.Common.GenAvatar
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  # where the static cache keeps the response for an address
  defp cached_file(dest, path),
    do: Path.join([dest, String.trim_leading(path, "/"), "index.html"])

  setup do
    # Unique suffix per test run to avoid parallel-test collisions
    uid = :rand.uniform(1_000_000)
    user_id = "testuser_#{uid}"
    path = GenAvatar.path(user_id)

    # Use the StaticGenerator purge adapter — this activates the before_send
    # hook in MaybeStaticGeneratorPlug that writes each response to disk
    Process.put(
      [:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters],
      [PurgeAdapter]
    )

    # Write static files synchronously so assertions can check them immediately
    Process.put(
      [:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write],
      true
    )

    dest = StaticGenerator.dest_path()
    on_exit(fn -> File.rm_rf!(Path.join([dest, "gen_avatar", user_id])) end)

    {:ok, resp: get(build_conn(), path), user_id: user_id, path: path, dest: dest}
  end

  test "returns 200 with SVG content", %{resp: conn} do
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "svg"
  end

  test "does not emit Set-Cookie, but sets public Cache-Control header", %{resp: conn} do
    assert get_resp_header(conn, "set-cookie") == []

    assert [cache_control] = get_resp_header(conn, "cache-control")
    assert cache_control =~ "public"
    assert cache_control =~ "max-age="
    assert cache_control =~ "s-maxage="
    assert cache_control =~ "stale-while-revalidate="
  end

  test "second request is served from the static cache", _ctx do
    # Write a sentinel file directly into the real static dir that Plug.Static reads from.
    static_dir = Application.app_dir(:bonfire, "priv/static/public")
    path = Path.join([static_dir, "gen_avatar", "cache_serving_test", "index.html"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "CACHED_SENTINEL")
    on_exit(fn -> File.rm_rf!(Path.dirname(path)) end)

    conn = get(build_conn(), "/gen_avatar/cache_serving_test")
    assert conn.status == 200
    assert conn.resp_body == "CACHED_SENTINEL"
  end

  # an account signed in without a chosen profile is signed in for `GuestOnly` too, so serving it the guest page made "Sign in" bounce straight back to that page
  test "an account signed in without a profile is not served the guest cache", _ctx do
    static_dir = Application.app_dir(:bonfire, "priv/static/public")
    signed = GenAvatar.path("account_only_test")
    path = cached_file(static_dir, signed)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "CACHED_SENTINEL")
    on_exit(fn -> File.rm_rf!(Path.join([static_dir, "gen_avatar", "account_only_test"])) end)

    conn = get(conn(account: "account-only-session"), signed)
    assert conn.status == 200
    refute conn.resp_body == "CACHED_SENTINEL"
    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  describe "purging via StaticGenerator adapter" do
    test "request writes a static file to the cache, and bust_urls deletes the cached file for the response URL",
         %{path: url, dest: dest} do
      path = cached_file(dest, url)
      assert File.exists?(path)

      assert PurgeAdapter.bust_urls([url]) == :ok

      refute File.exists?(path)
    end

    test "sets surrogate-key and cache-tag headers containing the avatar ID, and bust_tags uses the surrogate-key from the response to purge",
         %{resp: conn, user_id: user_id, dest: dest} do
      assert [cache_tag] = get_resp_header(conn, "cache-tag")
      assert cache_tag =~ user_id

      [surrogate_tag] = get_resp_header(conn, "surrogate-key")
      assert surrogate_tag =~ user_id

      assert cache_tag == surrogate_tag

      path = Path.join([dest, cache_tag, "index.html"])
      assert File.exists?(path)

      assert PurgeAdapter.bust_tags([cache_tag]) == :ok

      refute File.exists?(path)
    end

    test "bust_tags purges all avatars when using the shared tag prefix", %{dest: dest} do
      uid = :rand.uniform(1_000_000)
      alice = "alice_#{uid}"
      bob = "bob_#{uid}"

      get(build_conn(), GenAvatar.path(alice))
      get(build_conn(), GenAvatar.path(bob))

      alice_path = cached_file(dest, GenAvatar.path(alice))
      bob_path = cached_file(dest, GenAvatar.path(bob))
      assert File.exists?(alice_path)
      assert File.exists?(bob_path)

      on_exit(fn ->
        File.rm_rf!(Path.join([dest, "gen_avatar", alice]))
        File.rm_rf!(Path.join([dest, "gen_avatar", bob]))
      end)

      assert PurgeAdapter.bust_tags(["gen_avatar"]) == :ok

      refute File.exists?(alice_path)
      refute File.exists?(bob_path)
    end
  end

  describe "memory cache (threshold-based Cachex promotion)" do
    # Each test in this describe block runs with a threshold of 2 disk hits.
    # The outer setup already wrote the disk file on the first (controller) request.
    # Subsequent requests in each test hit Plug.Static (disk) and increment the counter.

    setup %{path: path} do
      Process.put(
        [:bonfire_ui_common, MaybeStaticGeneratorPlug, :memory_cache_threshold],
        2
      )

      on_exit(fn ->
        Cache.remove("static_gen:#{path}")
        Cache.remove("static_gen_hits:#{path}")
      end)

      :ok
    end

    test "memory cache is not populated before threshold is reached", %{path: path} do
      # One disk hit — below threshold of 2
      get(build_conn(), path)

      refute Cache.get!("static_gen:#{path}")
    end

    test "URL is promoted to memory cache after threshold disk hits", %{path: path} do
      get(build_conn(), path)
      get(build_conn(), path)

      assert {_content_type, body} = Cache.get!("static_gen:#{path}")
      assert body =~ "<svg"
    end

    test "subsequent request is served from memory after promotion", %{
      path: path,
      dest: dest
    } do
      get(build_conn(), path)
      get(build_conn(), path)

      assert Cache.get!("static_gen:#{path}")

      # Remove disk file — next request must be served from memory, not disk or controller
      File.rm!(cached_file(dest, path))

      conn = get(build_conn(), path)
      assert conn.status == 200
      assert conn.resp_body =~ "<svg"
    end

    test "bust_urls evicts the URL from memory cache", %{path: path} do
      get(build_conn(), path)
      get(build_conn(), path)
      assert Cache.get!("static_gen:#{path}")

      PurgeAdapter.bust_urls([path])

      refute Cache.get!("static_gen:#{path}")
    end

    test "bust_tags evicts the URL from memory cache", %{path: path, user_id: user_id} do
      get(build_conn(), path)
      get(build_conn(), path)
      assert Cache.get!("static_gen:#{path}")

      PurgeAdapter.bust_tags(["gen_avatar/#{user_id}"])

      refute Cache.get!("static_gen:#{path}")
    end
  end
end
