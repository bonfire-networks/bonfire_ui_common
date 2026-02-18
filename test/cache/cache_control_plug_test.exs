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
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  setup do
    # Unique suffix per test run to avoid parallel-test collisions
    uid = :rand.uniform(1_000_000)
    user_id = "testuser_#{uid}"

    # Use the StaticGenerator purge adapter — this activates the before_send
    # hook in MaybeStaticGeneratorPlug that writes each response to disk
    Process.put(
      [:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters],
      [PurgeAdapter]
    )

    dest = StaticGenerator.dest_path()
    on_exit(fn -> File.rm_rf!(Path.join([dest, "gen_avatar", user_id])) end)

    {:ok, resp: get(build_conn(), "/gen_avatar/#{user_id}"), user_id: user_id, dest: dest}
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

  describe "purging via StaticGenerator adapter" do
    test "request writes a static file to the cache, and bust_urls deletes the cached file for the response URL",
         %{user_id: user_id, dest: dest} do
      path = Path.join([dest, "gen_avatar", user_id, "index.html"])
      assert File.exists?(path)

      assert PurgeAdapter.bust_urls(["/gen_avatar/#{user_id}"]) == :ok

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

      get(build_conn(), "/gen_avatar/#{alice}")
      get(build_conn(), "/gen_avatar/#{bob}")

      alice_path = Path.join([dest, "gen_avatar", alice, "index.html"])
      bob_path = Path.join([dest, "gen_avatar", bob, "index.html"])
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

    setup %{user_id: user_id} do
      Process.put(
        [:bonfire_ui_common, MaybeStaticGeneratorPlug, :memory_cache_threshold],
        2
      )

      on_exit(fn ->
        Cache.remove("static_gen:/gen_avatar/#{user_id}")
        Cache.remove("static_gen_hits:/gen_avatar/#{user_id}")
      end)

      :ok
    end

    test "memory cache is not populated before threshold is reached", %{user_id: user_id} do
      # One disk hit — below threshold of 2
      get(build_conn(), "/gen_avatar/#{user_id}")

      refute Cache.get!("static_gen:/gen_avatar/#{user_id}")
    end

    test "URL is promoted to memory cache after threshold disk hits", %{user_id: user_id} do
      get(build_conn(), "/gen_avatar/#{user_id}")
      get(build_conn(), "/gen_avatar/#{user_id}")

      assert {_content_type, body} = Cache.get!("static_gen:/gen_avatar/#{user_id}")
      assert body =~ "<svg"
    end

    test "subsequent request is served from memory after promotion", %{
      user_id: user_id,
      dest: dest
    } do
      get(build_conn(), "/gen_avatar/#{user_id}")
      get(build_conn(), "/gen_avatar/#{user_id}")

      assert Cache.get!("static_gen:/gen_avatar/#{user_id}")

      # Remove disk file — next request must be served from memory, not disk or controller
      File.rm!(Path.join([dest, "gen_avatar", user_id, "index.html"]))

      conn = get(build_conn(), "/gen_avatar/#{user_id}")
      assert conn.status == 200
      assert conn.resp_body =~ "<svg"
    end

    test "bust_urls evicts the URL from memory cache", %{user_id: user_id} do
      get(build_conn(), "/gen_avatar/#{user_id}")
      get(build_conn(), "/gen_avatar/#{user_id}")
      assert Cache.get!("static_gen:/gen_avatar/#{user_id}")

      PurgeAdapter.bust_urls(["/gen_avatar/#{user_id}"])

      refute Cache.get!("static_gen:/gen_avatar/#{user_id}")
    end

    test "bust_tags evicts the URL from memory cache", %{user_id: user_id} do
      get(build_conn(), "/gen_avatar/#{user_id}")
      get(build_conn(), "/gen_avatar/#{user_id}")
      assert Cache.get!("static_gen:/gen_avatar/#{user_id}")

      PurgeAdapter.bust_tags(["gen_avatar/#{user_id}"])

      refute Cache.get!("static_gen:/gen_avatar/#{user_id}")
    end
  end
end
