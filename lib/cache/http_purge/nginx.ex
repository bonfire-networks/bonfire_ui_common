defmodule Bonfire.UI.Common.Cache.HTTPPurge.Nginx do
  @moduledoc """
  HTTP cache purge adapter for Nginx.

  Sends `PURGE` requests to the Nginx instance configured via `NGINX_URL`
  (defaults to `http://localhost:80`).

  > #### Base nginx is not supported {: .warning}
  > The standard `nginx` package has no `PURGE` support. You need either:
  > - The free [`ngx_cache_purge`](https://github.com/FRiCKLE/ngx_cache_purge) module by FRiCKLE — included in `nginx-extras` on Debian/Ubuntu, or added via the official [nginx modules build system](https://github.com/nginx/docker-nginx/blob/master/modules/README.md) for Docker deployments.
  > - Nginx Plus (commercial).

  Nginx Plus users can also use this adapter — `PURGE` method and wildcard
  syntax are identical. The commercial `purger=on` option in `proxy_cache_path` is not required; it only affects background disk cleanup speed.

  ## Tag-based purging

  `bust_tags/1` sends a wildcard `PURGE` request per tag (e.g. tag `"post-123"` → `PURGE /post-123*`). Surrogate keys set via `surrogate-key` / `cache-tag` headers should therefore correspond to URL path prefixes. Matching entries are removed from the cache immediately; disk files are reclaimed on next access or natural expiry.
  """

  @behaviour Bonfire.Common.Cache.HTTPPurge
  use Untangle

  def bust_urls(urls) when is_list(urls) do
    Enum.each(urls, &purge_one/1)
    :ok
  end

  def bust_tags(tags) when is_list(tags) do
    Enum.each(tags, fn tag -> purge_one("/#{tag}*") end)
    :ok
  end

  defp purge_one(path) do
    base = Bonfire.Common.Cache.HTTPPurge.config(:nginx_url) || "http://localhost:80"
    url = "#{base}#{path}"

    case Req.request(method: :purge, url: url) do
      {:ok, _} -> :ok
      {:error, reason} -> error(reason, "Nginx purge failed for #{path}")
    end
  end
end
