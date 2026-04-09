defmodule Bonfire.UI.Common.MaybeStaticGeneratorPlug do
  @moduledoc """
  Plug that serves cacheable public pages from a one or two tier cache for unauthenticated guests, before the request reaches Phoenix routing:

  1. **Memory cache** (Cachex or Nebulex ETS backend) — fastest path. Only active when
     `memory_cache_threshold` is configured (default: disabled) and `cache_backend` is an
     ETS-based backend. Pages are promoted from disk to memory after reaching the threshold hit count.

  2. **Disk cache** — one of:
     - `cache_backend: SimpleDiskCache` or `cache_backend: DiskLFUCache` — sole cache tier, served
       via `send_file` using `return: :path`. No Plug.Static involvement.
     - `disk_cache_backend: SimpleDiskCache` or `disk_cache_backend: DiskLFUCache` — dedicated disk
       tier used after an ETS `cache_backend` miss. Replaces `Plug.Static` + `priv/static/public/`.
     - Default (no disk backend configured): `Plug.Static` serves pre-generated HTML files from
       `priv/static/public/<path>/index.html`. Always active for unauthenticated requests.

  If all tiers miss (or are bypassed for authenticated users / non-empty query strings), the plug
  passes through to the normal Phoenix/LiveView pipeline unchanged.

  Static files must be pre-generated via `Bonfire.UI.Common.StaticGenerator.generate/2` (or the
  Oban batch job) for the default disk tier to serve anything. When a `disk_cache_backend` is
  configured, files are written to it automatically via `cache_response/3`. Optionally, when
  `purgeable: true` is set on the pipeline/route definition, a `before_send` hook also writes fresh
  unauthenticated responses to the disk cache automatically, keeping it warm on misses.

  ## Configuration

      config :bonfire_ui_common, Bonfire.UI.Common.MaybeStaticGeneratorPlug,
        # ETS-based memory cache backend. Defaults to Cachex. Can be set to any Nebulex cache
        # module (e.g. Bonfire.Common.Cache.NebulexLocalCache), or to a disk-based backend
        # (SimpleDiskCache / DiskLFUCache) to use it as the sole cache tier.
        cache_backend: Cachex,
        # Dedicated disk cache backend (optional). When set, replaces Plug.Static with disk-based
        # serving via send_file (zero-copy). Valid values: SimpleDiskCache, DiskLFUCache.
        # disk_cache_backend: Bonfire.Common.Cache.SimpleDiskCache,
        # Number of disk-cache hits before a page is promoted to the in-memory ETS cache.
        # Set to nil or 0 (default) to disable the memory cache tier entirely.
        memory_cache_threshold: 10,
        # How long a page stays in the memory cache after promotion (default: 5 minutes).
        memory_cache_ttl: :timer.minutes(5),
        # How long the per-URL hit counter lives (default: 1 hour).
        memory_hits_ttl: :timer.hours(1)
  """

  use Plug.Builder
  import Plug.Conn
  import Untangle

  use Bonfire.Common.Config
  alias Bonfire.Common.Cache
  alias Bonfire.Common.Cache.SimpleDiskCache
  alias Bonfire.Common.Cache.DiskLFUCache
  alias Bonfire.UI.Common.StaticGenerator

  plug(:maybe_make_request_path_static)
  plug(:maybe_serve_static)
  plug(:maybe_register_cache_writer)

  # Plug.Static.call/2 requires initialized opts (a struct/map with :at, :only_rules, etc).
  # Passing a raw keyword list falls through to the no-op clause and never serves files.
  @static_opts Plug.Static.init(
                 at: "/",
                 from: {:bonfire, "priv/static/#{Bonfire.UI.Common.StaticGenerator.base_path()}"}
               )

  @memory_cache_prefix "static_gen:"
  @hits_cache_prefix "static_gen_hits:"

  @disk_backends [SimpleDiskCache, DiskLFUCache]

  def maybe_serve_static(conn, _opts) do
    request_path = conn.request_path || "/"
    #  workaround for URLs like /@user@localhost:4000
    if not String.contains?(request_path, ":") do
      url = conn.private[:original_request_path] || conn.request_path
      config = plug_config()

      case memory_cache_get(url, config) do
        {content_type, body} ->
          info(url, "serving from memory cache")

          conn
          |> put_resp_content_type(content_type)
          |> send_resp(200, body)
          |> halt()

        body when is_binary(body) ->
          info(url, "serving from memory cache (html)")

          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, body)
          |> halt()

        _ ->
          case disk_cache_get(url, config) do
            path when is_binary(path) ->
              # Disk cache hit: serve zero-copy and count the hit so that frequently-accessed
              # pages are promoted to the ETS memory tier after `memory_cache_threshold` hits.
              info(url, "serving from disk cache via send_file")

              content_type = StaticGenerator.get_content_type(url, config)
              |> info("found cached content_type")

              conn = conn |> put_resp_content_type(content_type || "text/html") |> send_file(200, path, 0, :all) |> halt()

              maybe_track_and_promote(content_type, url, conn, config)

              conn

            _ ->
              # Disk cache miss — fall through to Phoenix so it renders the page;
              # the before_send hook will then write the response to the disk cache.
              conn
          end
      end
    else
      conn
    end
  end

  def memory_cache_get(url, config \\ nil) do
    config = config || plug_config()
    threshold = config[:memory_cache_threshold]

    if not is_nil(threshold) and threshold != 0 do
      backend = config[:cache_backend]

      # skip memory cache for disk-only backends
      if backend not in @disk_backends do
        Cache.get!(@memory_cache_prefix <> url, cache_backend: backend)
      end
    end
  end

  defp disk_cache_get(url, config) do
    backend = disk_cache_backend(config)

    if backend do
      extra =
        if backend == SimpleDiskCache,
          do: [root_path: config[:root_path] || StaticGenerator.dest_path()],
          else: []

      Cache.get!(url, [cache_backend: backend, return: :path] ++ extra)
    end
  end

  # Returns the effective disk cache backend.
  # Explicit disk_cache_backend takes priority; if cache_backend is itself a disk type it acts
  # as the sole disk tier; otherwise fall back to SimpleDiskCache (plain priv/static/public/).
  defp disk_cache_backend(config) do
    config[:disk_cache_backend] ||
      (if config[:cache_backend] in @disk_backends, do: config[:cache_backend]) ||
      SimpleDiskCache
  end

  defp maybe_track_and_promote(content_type, url, conn, config) do
    with threshold when not is_nil(threshold) and threshold != 0 <- config[:memory_cache_threshold] do
      hits_key = @hits_cache_prefix <> url

      # track hits in the default (ETS) cache
      cache_backend = Cache.default_cache_backend()

      new_hits =
        (Cache.get!(hits_key, cache_backend: cache_backend) || 0) + 1

      Cache.put(hits_key, new_hits,
        cache_backend: cache_backend,
        expire: config[:memory_hits_ttl] || :timer.hours(1)
      )

      memory_backend = config[:cache_backend]

      if new_hits >= threshold and memory_backend not in @disk_backends do
        backend = disk_cache_backend(config)
        root_path = config[:root_path] || StaticGenerator.dest_path()

        content_type =
        (content_type || "text/html")
        #   (conn |> get_resp_header("content-type") |> List.first() || "text/html")
          |> flood("promot_content_type")

        with {:ok, body} when is_binary(body) <-
               Bonfire.Common.Cache.Backend.get(backend, url, root_path: root_path) do
          info(url, "promoting to memory cache after #{new_hits} disk hits")
          value = if String.starts_with?(content_type, "text/html"), do: body, else: {content_type, body}

          Cache.put(@memory_cache_prefix <> url, value,
            cache_backend: memory_backend,
            expire: config[:memory_cache_ttl] || :timer.minutes(5)
          )
        end
      end
    end
  end

  defp plug_config do
    Bonfire.Common.Config.get(__MODULE__) || []
  end

  @doc "Registers a before_send hook to write the response body to the static cache when the StaticGenerator purge adapter is active (configured via HTTPPurge adapters, or Process.put in tests), but only for unauthenticated responses that carry a surrogate-key header (set by CacheControlPlug, purgeable: true)."
  def maybe_register_cache_writer(conn, _opts) do
    if static_generator_adapter?() do
      register_before_send(conn, &maybe_write_static_cache/1)
    else
      conn
    end
  end

  defp maybe_write_static_cache(conn) do
    if cacheable_response?(conn) do

      # Use the original request path saved before maybe_make_request_path_static
      # rewrote it to include /index.html — otherwise we'd write to the wrong path.
      url = conn.private[:original_request_path] || conn.request_path

      info(url, "cache response")

      content_type =
          (conn |> get_resp_header("content-type") |> List.first() || "text/html")
          |> flood("content_type1")

      tags = conn |> get_resp_header("surrogate-key") |> Enum.flat_map(&String.split/1)

      config = plug_config()
      opts = [
        tags: tags,
        disk_cache_backend: config[:disk_cache_backend] || disk_cache_backend(config),
        output_dir: config[:root_path]
      ]
      # Write to disk asynchronously so the response is not delayed by the file write.
      # In tests, use Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write], true)
      # to write synchronously so assertions can check the file immediately.
      if Process.get([:bonfire_ui_common, Bonfire.UI.Common.MaybeStaticGeneratorPlug, :sync_static_write], false) do
        Bonfire.UI.Common.StaticGenerator.cache_response(url, content_type, conn.resp_body, [async: false] ++ opts)
      else
        Task.start(fn ->
          Bonfire.UI.Common.StaticGenerator.cache_response(url, content_type, conn.resp_body, opts)
        end)
      end
    end

    conn
  end

  # A response is written to the static cache when:
  #   1. The route went through MaybeStaticGeneratorPlug for an unauthenticated
  #      request — the plug sets :static_cacheable in conn.private as the opt-in signal.
  #   2. The controller did not authenticate the user (assigns check fires after the
  #      LiveView/controller runs and may have set current_user).
  #   3. No session-specific flash messages are present in the rendered HTML.
  defp cacheable_response?(conn) do
    conn.private[:static_cacheable] == true and
      not authenticated?(conn) and
      not has_flash?(conn)
  end

  # Use value-based checks rather than Map.has_key? so that assigns like
  # current_user: nil (set by some LiveView on_mount hooks even for guests)
  # do not incorrectly block caching of unauthenticated responses.
  defp authenticated?(conn) do
    not is_nil(conn.assigns[:current_user]) or not is_nil(conn.assigns[:current_account])
  end

  # Don't cache responses that contain flash messages — flash is session-specific
  # and must not be served to other users from the shared static cache.
  defp has_flash?(conn) do
    flash = conn.assigns[:flash] || %{}
    flash != %{}
  end

  defp static_generator_adapter? do
    Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator in Bonfire.Common.Cache.HTTPPurge.adapters()
  end

  # do not serve cache when logged in
  def maybe_make_request_path_static(%{assigns: %{current_account: %{}}} = conn, _),
    do: conn

  def maybe_make_request_path_static(%{assigns: %{current_user: %{}}} = conn, _), do: conn

  # Don't serve the cached HTML if the URI has a non-empty query string —
  # query params may change what the page shows.
  def maybe_make_request_path_static(%{query_string: query_string} = conn, _)
      when query_string != "",
      do: conn

  # For any other unauthenticated request, try to serve from static disk cache.
  # Uses session (not assigns) because current_user may not be loaded yet in the
  # :cacheable pipeline. Falls through to the controller if no file exists.
  def maybe_make_request_path_static(conn, _) do
    if !get_session(conn, :current_user_id) do
      # Save original path before StaticGeneratedPlug rewrites request_path to
      # include /index.html — the cache writer needs the unmodified URL.
      # Also mark this connection as eligible for static caching — used by
      # cacheable_response? to decide whether to write the response to disk.
      conn
      |> put_private(:original_request_path, conn.request_path)
      |> put_private(:static_cacheable, true)
      |> Bonfire.UI.Common.StaticGeneratedPlug.make_request_path_static()
    else
      # info("do not use cache when signed in")
      conn
    end
  end
end