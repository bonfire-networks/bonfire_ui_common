defmodule Bonfire.UI.Common.StaticCacheStatusTest do
  @moduledoc "Only a 200 response is written to the static cache: any other answer written there would be served as the page."
  use ExUnit.Case, async: false
  @moduletag :ui

  import Plug.Test
  import Plug.Conn

  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  setup do
    Process.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [PurgeAdapter])
    Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write], true)

    path = "/static_cache_status_#{System.unique_integer([:positive])}"
    file = Path.join([StaticGenerator.dest_path(), String.trim_leading(path, "/"), "index.html"])
    on_exit(fn -> File.rm_rf!(Path.dirname(file)) end)

    {:ok, path: path, cache_file: file}
  end

  # a guest request the plug marked cacheable, answered with `status`
  defp answer(path, status) do
    conn(:get, path)
    |> put_private(:static_cacheable, true)
    |> MaybeStaticGeneratorPlug.maybe_register_cache_writer([])
    |> send_resp(status, "<html>answer #{status}</html>")
  end

  test "a 200 response is written", %{path: path, cache_file: file} do
    answer(path, 200)
    assert File.read!(file) =~ "answer 200"
  end

  test "a 404 response is not written", %{path: path, cache_file: file} do
    answer(path, 404)
    refute File.exists?(file)
  end

  test "a redirect and a server error are not written", %{path: path, cache_file: file} do
    answer(path, 302)
    answer(path, 500)
    refute File.exists?(file)
  end
end
