defmodule Bonfire.UI.Common.QueryStringCacheTest do
  @moduledoc """
  Verifies that MaybeStaticGeneratorPlug caches embed routes per unique query
  string using a hash-keyed subdirectory, while leaving non-embed routes
  (without cache_query_string: true on CacheControlPlug) uncached.
  """

  use Bonfire.UI.Common.ConnCase, async: true

  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  # 8-char sha256 hex of the given query string
  defp qs_hash(qs) do
    :crypto.hash(:sha256, qs) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  defp hashed_path(path, qs), do: path <> "/_qs_" <> qs_hash(qs)

  setup do
    Process.put(
      [:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters],
      [PurgeAdapter]
    )

    Process.put(
      [:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write],
      true
    )

    dest = StaticGenerator.dest_path()
    {:ok, dest: dest}
  end

  describe "embed route with cache_query_string: true" do
    setup %{dest: dest} do
      qs = "theme=dracula"
      path = "/instance/pins/embed"
      hashed = hashed_path(path, qs)
      cache_file = Path.join([dest, String.trim_leading(hashed, "/"), "index.html"])
      on_exit(fn -> File.rm_rf!(Path.dirname(cache_file)) end)
      {:ok, qs: qs, path: path, hashed: hashed, cache_file: cache_file}
    end

    test "first request writes hash-keyed cache file", %{cache_file: cache_file} do
      get(build_conn(), "/instance/pins/embed?theme=dracula")
      assert File.exists?(cache_file)
    end

    test "different query strings produce different cache entries", %{dest: dest} do
      qs1 = "theme=dark"
      qs2 = "theme=light"
      path = "/instance/pins/embed"

      file1 = Path.join([dest, String.trim_leading(hashed_path(path, qs1), "/"), "index.html"])
      file2 = Path.join([dest, String.trim_leading(hashed_path(path, qs2), "/"), "index.html"])

      on_exit(fn ->
        File.rm_rf!(Path.dirname(file1))
        File.rm_rf!(Path.dirname(file2))
      end)

      get(build_conn(), "/instance/pins/embed?#{qs1}")
      get(build_conn(), "/instance/pins/embed?#{qs2}")

      assert File.exists?(file1)
      assert File.exists?(file2)
      assert file1 != file2
    end

    test "second request is served from cache", %{cache_file: cache_file} do
      # Prime the cache
      get(build_conn(), "/instance/pins/embed?theme=dracula")
      assert File.exists?(cache_file)

      # Overwrite with a sentinel
      File.write!(cache_file, "CACHED_SENTINEL")

      conn = get(build_conn(), "/instance/pins/embed?theme=dracula")
      assert conn.status == 200
      assert conn.resp_body == "CACHED_SENTINEL"
    end

    test "no cache file written when user is authenticated", %{cache_file: cache_file} do
      account = fake_account!()
      user = fake_user!(account)

      conn =
        build_conn()
        |> init_test_session(%{current_user_id: user.id})

      get(conn, "/instance/pins/embed?theme=dracula")
      refute File.exists?(cache_file)
    end
  end

  describe "route without cache_query_string opt" do
    test "query string does NOT produce a _qs_ cache file", %{dest: dest} do
      # /feed uses the plain browser pipeline, no cache_query_string: true
      qs = "page=2"
      path = "/feed"

      cache_file =
        Path.join([dest, String.trim_leading(hashed_path(path, qs), "/"), "index.html"])

      on_exit(fn -> File.rm_rf!(Path.dirname(cache_file)) end)

      get(build_conn(), "/feed?page=2")
      refute File.exists?(cache_file)
    end
  end
end
