defmodule Bonfire.UI.Common.CacheControlPlug do
  @moduledoc """
  Plug for setting HTTP cache-control headers on public (unauthenticated) responses, and for tagging responses with surrogate keys for targeted CDN purging. 

  ## Options

  - `purgeable: true` — declare that relevant mutations for this page call
    `Bonfire.Common.Cache.bust_http_*` on write. Enables longer default TTLs
    because stale content can be explicitly evicted. Defaults to `false`.
  - `ttl:` — explicit browser max-age in seconds (overrides ENV and purgeable defaults)
  - `cdn_ttl:` — explicit s-maxage in seconds (overrides ENV and purgeable defaults)
  - `swr:` — explicit stale-while-revalidate in seconds (overrides ENV default)

  ## Default TTLs

  Without purging (`purgeable: false`, the safe default — content may go stale):
  - Browser `max-age`: `CACHE_PAGE_TTL` (default: 1 minute)
  - CDN `s-maxage`: `CACHE_PAGE_CDN_TTL` (default: same as browser TTL)

  With purging (`purgeable: true` — stale content will be evicted on write):
  - Browser `max-age`: `CACHE_PURGEABLE_PAGE_TTL` (default: 5 minutes)
  - CDN `s-maxage`: `CACHE_PURGEABLE_CDN_TTL` (default: 1 hour)

  Shared:
  - `stale-while-revalidate`: `CACHE_PAGE_SWR` (default: 30 seconds)

  ## Usage

  > #### Do not use with CSRF protection {: .warning}
  > This plug must **not** be combined with `plug :protect_from_forgery` —
  > that plug writes a CSRF cookie on every request, which CDNs would then
  > serve to other users. Reading the session via `plug :fetch_session` is
  > fine (and used by the `:cacheable` pipeline to detect authenticated users);
  > just ensure the session is never *modified* so no `Set-Cookie` is emitted.

      # Conservative — no purging on mutations for this page
      plug Bonfire.UI.Common.CacheControlPlug

      # Longer TTLs — mutations call bust_http_* on write
      plug Bonfire.UI.Common.CacheControlPlug, purgeable: true

      # Explicit TTLs
      plug Bonfire.UI.Common.CacheControlPlug, ttl: 120, cdn_ttl: 3600

  To tag a response with surrogate keys for targeted purging:

      conn |> Bonfire.UI.Common.CacheControlPlug.tag_response(["post-\#{post.id}"])
  """

  import Plug.Conn

  def init(opts), do: opts

  # Skip caching for authenticated users
  def call(%{assigns: %{current_user: %{}}} = conn, _opts), do: conn
  def call(%{assigns: %{current_account: %{}}} = conn, _opts), do: conn

  def call(conn, opts) do
    purgeable? = opts[:purgeable] == true
    ttl = opts[:ttl] || default_ttl(purgeable?)
    cdn_ttl = opts[:cdn_ttl] || default_cdn_ttl(purgeable?, ttl)
    swr = opts[:swr] || default_swr()

    conn
    |> put_resp_header(
      "cache-control",
      "public, max-age=#{ttl}, s-maxage=#{cdn_ttl}, stale-while-revalidate=#{swr}"
    )
    # Reset session write intent so no Set-Cookie is emitted. Some pipeline
    # plugs (e.g. Cldr.Plug.SetLocale) may touch the session even for
    # cacheable routes. Resetting to nil here (after all pipeline plugs have
    # run but before before_send fires) prevents Plug.Session from writing
    # the cookie, which would poison any CDN or static-file cache.
    |> put_private(:plug_session_info, nil)
  end

  @doc "Set Surrogate-Key (Varnish xkey) and Cache-Tag (Cloudflare) headers on a conn."
  def tag_response(conn, tags) when is_list(tags) do
    tag_string = Enum.join(tags, " ")

    conn
    |> put_resp_header("surrogate-key", tag_string)
    |> put_resp_header("cache-tag", tag_string)
  end

  # Without purging: short TTLs — stale content cannot be evicted
  defp default_ttl(false) do
    String.to_integer(System.get_env("CACHE_PAGE_TTL", "#{div(to_timeout(minute: 1), 1_000)}"))
  end

  # With purging: longer browser TTL — mutations will evict stale content
  defp default_ttl(true) do
    String.to_integer(
      System.get_env("CACHE_PURGEABLE_PAGE_TTL", "#{div(to_timeout(minute: 5), 1_000)}")
    )
  end

  # Without purging: CDN TTL matches browser — no advantage to caching longer
  defp default_cdn_ttl(false, ttl) do
    String.to_integer(System.get_env("CACHE_PAGE_CDN_TTL", "#{ttl}"))
  end

  # With purging: CDN can cache much longer — explicit purge will evict on write
  defp default_cdn_ttl(true, _ttl) do
    String.to_integer(
      System.get_env("CACHE_PURGEABLE_CDN_TTL", "#{div(to_timeout(hour: 1), 1_000)}")
    )
  end

  defp default_swr do
    String.to_integer(System.get_env("CACHE_PAGE_SWR", "#{div(to_timeout(second: 30), 1_000)}"))
  end
end
