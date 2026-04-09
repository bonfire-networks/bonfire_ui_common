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

  The disk backend permutation block runs the same suite for each supported
  disk cache backend: default (write_file/SimpleDiskCache), and DiskLFUCache.
  """

  use Bonfire.UI.Common.ConnCase, async: true

  alias Bonfire.Common.Cache
  alias Bonfire.Common.Cache.Backend, as: CacheBackend
  alias Bonfire.Common.Cache.DiskLFUCache
  alias Bonfire.Common.Cache.SimpleDiskCache
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  setup do
    uid = :rand.uniform(1_000_000)
    user_id = "testuser_#{uid}"

    Process.put(
      [:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters],
      [PurgeAdapter]
    )

    Process.put(
      [:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write],
      true
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
    static_dir = Application.app_dir(:bonfire, "priv/static/public")
    path = Path.join([static_dir, "gen_avatar", "cache_serving_test", "index.html"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "CACHED_SENTINEL")
    on_exit(fn -> File.rm_rf!(Path.dirname(path)) end)

    conn = get(build_conn(), "/gen_avatar/cache_serving_test")
    assert conn.status == 200
    assert conn.resp_body == "CACHED_SENTINEL"
  end

  # ---------------------------------------------------------------------------
  # Disk backend permutations — run the purge + memory cache suite for each
  # ---------------------------------------------------------------------------

  disk_backend_permutations = [
    {nil, :disk_cache_backend, "default (SimpleDiskCache fallback)"},
    {DiskLFUCache, :disk_cache_backend, "DiskLFU as disk_cache_backend"},
    {DiskLFUCache, :cache_backend, "DiskLFU as sole cache_backend"}
  ]

  for {disk_backend, key, label} <- disk_backend_permutations do
    describe label do
      setup %{user_id: user_id} do
        root = Path.join(System.tmp_dir!(), "bonfire_test_#{:rand.uniform(1_000_000)}")
        File.mkdir_p!(root)
        {:ok, lfu_pid} = DiskLFUCache.start_link(root_path: root, max_bytes: nil)

        config =
          [root_path: root]
          |> then(fn c ->
            case unquote(disk_backend) do
              nil -> c
              b -> Keyword.put(c, unquote(key), b)
            end
          end)

        Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug], config)

        on_exit(fn ->
          # GenServer.stop(lfu_pid)
          File.rm_rf!(root)
          Cache.remove("/gen_avatar/#{user_id}")
          Cache.remove("static_gen_hits:/gen_avatar/#{user_id}")
        end)

        resp = get(build_conn(), "/gen_avatar/#{user_id}")
        {:ok, root: root, resp: resp}
      end

      test "request writes a static file and bust_urls deletes it",
           %{user_id: user_id, root: root} do
        backend = unquote(disk_backend) || SimpleDiskCache
        assert {:ok, true} = CacheBackend.has_key?(backend, "/gen_avatar/#{user_id}", root_path: root)
        assert PurgeAdapter.bust_urls(["/gen_avatar/#{user_id}"]) == :ok
        assert {:ok, false} = CacheBackend.has_key?(backend, "/gen_avatar/#{user_id}", root_path: root)
      end

      test "bust_tags uses the surrogate-key from the response to purge",
           %{resp: conn, user_id: user_id, root: root} do
        assert [cache_tag] = get_resp_header(conn, "cache-tag")
        assert cache_tag =~ user_id
        assert [surrogate_tag] = get_resp_header(conn, "surrogate-key")
        assert cache_tag == surrogate_tag

        backend = unquote(disk_backend) || SimpleDiskCache
        assert {:ok, true} = CacheBackend.has_key?(backend, "/#{cache_tag}", root_path: root)
        assert PurgeAdapter.bust_tags([cache_tag]) == :ok
        assert {:ok, false} = CacheBackend.has_key?(backend, "/#{cache_tag}", root_path: root)
      end

      test "bust_tags purges all avatars under the shared tag prefix", %{root: root} do
        uid = :rand.uniform(1_000_000)
        alice = "alice_#{uid}"
        bob = "bob_#{uid}"

        get(build_conn(), "/gen_avatar/#{alice}")
        get(build_conn(), "/gen_avatar/#{bob}")

        backend = unquote(disk_backend) || SimpleDiskCache
        assert {:ok, true} = CacheBackend.has_key?(backend, "/gen_avatar/#{alice}", root_path: root)
        assert {:ok, true} = CacheBackend.has_key?(backend, "/gen_avatar/#{bob}", root_path: root)

        assert PurgeAdapter.bust_tags(["gen_avatar"]) == :ok
        assert {:ok, false} = CacheBackend.has_key?(backend, "/gen_avatar/#{alice}", root_path: root)
        assert {:ok, false} = CacheBackend.has_key?(backend, "/gen_avatar/#{bob}", root_path: root)
      end

      test "memory cache is not populated before threshold is reached", %{user_id: user_id} do
        get(build_conn(), "/gen_avatar/#{user_id}")
        refute Cache.get!("/gen_avatar/#{user_id}")
      end

      test "URL is promoted to memory cache after threshold disk hits", %{user_id: user_id} do
        existing = Process.get([:bonfire_ui_common, MaybeStaticGeneratorPlug], [])
        Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug], Keyword.put(existing, :memory_cache_threshold, 2))

        get(build_conn(), "/gen_avatar/#{user_id}")
        get(build_conn(), "/gen_avatar/#{user_id}")

        assert {_content_type, body} = Cache.get!("/gen_avatar/#{user_id}")
        assert body =~ "<svg"
      end

      test "subsequent request is served from memory after promotion",
           %{user_id: user_id, root: root} do
        existing = Process.get([:bonfire_ui_common, MaybeStaticGeneratorPlug], [])
        Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug], Keyword.put(existing, :memory_cache_threshold, 2))

        get(build_conn(), "/gen_avatar/#{user_id}")
        get(build_conn(), "/gen_avatar/#{user_id}")
        assert Cache.get!("/gen_avatar/#{user_id}")

        CacheBackend.delete(unquote(disk_backend) || SimpleDiskCache, "/gen_avatar/#{user_id}", root_path: root)

        conn = get(build_conn(), "/gen_avatar/#{user_id}")
        assert conn.status == 200
        assert conn.resp_body =~ "<svg"
      end

      test "bust_urls evicts the URL from memory cache", %{user_id: user_id} do
        existing = Process.get([:bonfire_ui_common, MaybeStaticGeneratorPlug], [])
        Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug], Keyword.put(existing, :memory_cache_threshold, 2))

        get(build_conn(), "/gen_avatar/#{user_id}")
        get(build_conn(), "/gen_avatar/#{user_id}")
        assert Cache.get!("/gen_avatar/#{user_id}")

        PurgeAdapter.bust_urls(["/gen_avatar/#{user_id}"])
        refute Cache.get!("/gen_avatar/#{user_id}")
      end

      test "bust_tags evicts the URL from memory cache", %{user_id: user_id} do
        existing = Process.get([:bonfire_ui_common, MaybeStaticGeneratorPlug], [])
        Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug], Keyword.put(existing, :memory_cache_threshold, 2))

        get(build_conn(), "/gen_avatar/#{user_id}")
        get(build_conn(), "/gen_avatar/#{user_id}")
        assert Cache.get!("/gen_avatar/#{user_id}")

        PurgeAdapter.bust_tags(["gen_avatar/#{user_id}"])
        refute Cache.get!("/gen_avatar/#{user_id}")
      end
    end
  end
end
