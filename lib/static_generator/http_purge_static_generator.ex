defmodule Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator do
  @moduledoc """
  HTTP cache purge adapter for `Bonfire.UI.Common.StaticGenerator`.

  Deletes pre-generated static HTML files from disk so they are re-generated
  on the next request. Pairs with `Bonfire.UI.Common.MaybeStaticGeneratorPlug`,
  which writes the static file when this adapter is active and the response
  carries a `surrogate-key` header (i.e. `purgeable: true`).

  Deletion is routed through `Cache.Backend.delete/3` using whichever disk backend
  is configured in `MaybeStaticGeneratorPlug`, defaulting to `SimpleDiskCache` (plain
  filesystem). This works uniformly across `SimpleDiskCache`, `DiskLFUCache`, etc.

  ## How it maps purge calls to files

  - `bust_urls/1` — deletes the cached entry for each URL path.
  - `bust_tags/1` — treats each tag as a path prefix and deletes all
    `index.html` files under `<dest>/<tag>/**`.
  """

  @behaviour Bonfire.Common.Cache.HTTPPurge

  use Untangle
  use Bonfire.Common.Config

  alias Bonfire.Common.Cache
  alias Bonfire.Common.Cache.Backend, as: CacheBackend
  alias Bonfire.Common.Cache.SimpleDiskCache
  alias Bonfire.Common.Cache.DiskLFUCache
  alias Bonfire.UI.Common.StaticGenerator

  @memory_cache_prefix "static_gen:"
  @hits_cache_prefix "static_gen_hits:"
  @disk_backends [SimpleDiskCache, DiskLFUCache]

  @doc "Deletes the cached static file and any memory cache entry for each URL path."
  def bust_urls(urls) when is_list(urls) do
    config = plug_config()
    dest = config[:root_path] || StaticGenerator.dest_path()
    info(dest, "bust_urls dest")

    Enum.each(urls, fn url ->
      info(url, "bust_urls deleting")
      CacheBackend.delete(disk_cache_backend(config), url, root_path: dest)
      Cache.remove(@memory_cache_prefix <> url)
    end)

    :ok
  end

  @doc """
  Deletes all cached static files whose path starts with the given tag,
  and evicts matching memory cache entries.

  Tags are treated as URL path prefixes, so `"gen_avatar"` purges all cached
  avatar files, and `"gen_avatar/alice"` purges just Alice's cached avatar.
  """
  def bust_tags(tags) when is_list(tags) do
    config = plug_config()
    dest = config[:root_path] || StaticGenerator.dest_path()
    info(dest, "bust_tags dest")

    Enum.each(tags, fn tag ->
      clean = String.trim_leading(tag, "/")

      CacheBackend.delete(disk_cache_backend(config), "/#{clean}", root_path: dest)
      bust_memory_for_url("/#{clean}")

      # Also delete all index.html files nested under the tag as a directory prefix
      glob = Path.join([dest, clean, "**", "index.html"])

      Enum.each(Path.wildcard(glob), fn file ->
        url =
          file
          |> String.replace_prefix(dest, "")
          |> String.replace_suffix("/index.html", "")

        CacheBackend.delete(disk_cache_backend(config), url, root_path: dest)
        bust_memory_for_url(url)
      end)
    end)

    :ok
  end

  defp bust_memory_for_url(url) do
    Cache.remove(@memory_cache_prefix <> url)
    Cache.remove(@hits_cache_prefix <> url)
  end

  # Returns the active disk backend, defaulting to SimpleDiskCache so
  # Cache.Backend always handles file deletion uniformly.
  defp disk_cache_backend(config) do
    config[:disk_cache_backend] ||
      (if config[:cache_backend] in @disk_backends, do: config[:cache_backend]) ||
      SimpleDiskCache
  end

  defp plug_config do
    Bonfire.Common.Config.get(Bonfire.UI.Common.MaybeStaticGeneratorPlug) || []
  end
end
