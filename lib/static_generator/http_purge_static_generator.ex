defmodule Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator do
  @moduledoc """
  HTTP cache purge adapter for `Bonfire.UI.Common.StaticGenerator`.

  Deletes pre-generated static HTML files from disk so they are re-generated
  on the next request. Pairs with `Bonfire.UI.Common.MaybeStaticGeneratorPlug`,
  which writes the static file when this adapter is active and the response
  carries a `surrogate-key` header (i.e. `purgeable: true`).

  ## How it maps purge calls to files

  - `bust_urls/1` — deletes `<dest>/<url>/index.html` for each URL path.
  - `bust_tags/1` — treats each tag as a path prefix and deletes all
    `index.html` files under `<dest>/<tag>/**`.

  The destination path is read from `Bonfire.UI.Common.StaticGenerator.dest_path/0`
  so both modules always agree on where files are stored.
  """

  @behaviour Bonfire.Common.Cache.HTTPPurge

  use Untangle

  alias Bonfire.Common.Cache
  alias Bonfire.UI.Common.StaticGenerator

  @memory_cache_prefix "static_gen:"
  @hits_cache_prefix "static_gen_hits:"

  @doc "Deletes the cached static file and any memory cache entry for each URL path."
  def bust_urls(urls) when is_list(urls) do
    dest = StaticGenerator.dest_path()
    info(dest, "bust_urls dest")

    Enum.each(urls, fn url ->
      path = Path.join([dest, String.trim_leading(url, "/"), "index.html"])
      info(path, "bust_urls deleting path")

      case File.rm(path) do
        :ok -> info("Purged static cache: #{path}")
        # Already gone — nothing to do
        {:error, :enoent} -> info("bust_urls: file not found (already gone): #{path}")
        {:error, reason} -> warn(reason, "Could not purge #{path}")
      end

      Cache.remove(@memory_cache_prefix <> url)
      # Cache.remove(@hits_cache_prefix <> url)
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
    dest = StaticGenerator.dest_path()
    info(dest, "bust_tags dest")

    Enum.each(tags, fn tag ->
      clean = String.trim_leading(tag, "/")

      # Delete exact path (tag == URL, no deeper nesting) + evict from memory
      exact = Path.join([dest, clean, "index.html"])
      info(exact, "bust_tags deleting exact path")
      File.rm(exact)
      bust_memory_for_url("/#{clean}")

      # Delete all index.html files under the tag as a directory prefix
      glob = Path.join([dest, clean, "**", "index.html"])
      matches = Path.wildcard(glob)
      info(matches, "bust_tags wildcard matches")

      Enum.each(matches, fn file ->
        File.rm(file)
        # Derive the URL from the file path: strip dest prefix and "/index.html" suffix
        url =
          file
          |> String.replace_prefix(dest, "")
          |> String.replace_suffix("/index.html", "")

        bust_memory_for_url(url)
      end)
    end)

    :ok
  end

  defp bust_memory_for_url(url) do
    Cache.remove(@memory_cache_prefix <> url)
    Cache.remove(@hits_cache_prefix <> url)
  end
end
