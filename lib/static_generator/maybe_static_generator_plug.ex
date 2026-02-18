defmodule Bonfire.UI.Common.MaybeStaticGeneratorPlug do
  use Plug.Builder
  import Plug.Conn
  import Untangle

  use Bonfire.Common.Config
  alias Bonfire.Common.Cache
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

  def maybe_serve_static(conn, _opts) do
    request_path = conn.request_path || "/"
    #  workaround for URLs like /@user@localhost:4000
    if not String.contains?(request_path, ":") do
      url = conn.private[:original_request_path] || conn.request_path

      case memory_cache_get(url) do
        {content_type, body} ->
          info(url, "serving from memory cache")

          conn
          |> put_resp_content_type(content_type)
          |> send_resp(200, body)
          |> halt()

        nil ->
          result = Plug.Static.call(conn, @static_opts)
          if result.halted, do: maybe_track_and_promote(url, result)
          result
      end
    else
      conn
    end
  end

  defp memory_cache_get(url) do
    threshold = memory_cache_threshold()

    if not is_nil(threshold) and threshold != 0 do
      Cache.get!(@memory_cache_prefix <> url)
    end
  end

  defp maybe_track_and_promote(url, conn) do
    with threshold when not is_nil(threshold) and threshold != 0 <- memory_cache_threshold() do
      hits_key = @hits_cache_prefix <> url
      new_hits = (Cache.get!(hits_key) || 0) + 1
      Cache.put(hits_key, new_hits, expire: memory_hits_ttl())

      if new_hits >= threshold do
        path =
          Path.join([
            StaticGenerator.dest_path(),
            String.trim_leading(url, "/"),
            "index.html"
          ])

        content_type =
          conn |> get_resp_header("content-type") |> List.first() || "text/html"

        with {:ok, body} <- File.read(path) do
          info(url, "promoting to memory cache after #{new_hits} disk hits")
          Cache.put(@memory_cache_prefix <> url, {content_type, body}, expire: memory_cache_ttl())
        end
      end
    end
  end

  defp memory_cache_threshold do
    Bonfire.Common.Config.get(
      [__MODULE__, :memory_cache_threshold],
      nil
    )
  end

  defp memory_cache_ttl do
    Bonfire.Common.Config.get(
      [__MODULE__, :memory_cache_ttl],
      :timer.minutes(5)
    )
  end

  defp memory_hits_ttl do
    Bonfire.Common.Config.get(
      [__MODULE__, :memory_hits_ttl],
      :timer.hours(1)
    )
  end

  # Register a before_send hook to write the response body to the static cache
  # when the StaticGenerator purge adapter is active (configured via HTTPPurge
  # adapters, or Process.put in tests). Only fires for unauthenticated responses
  # that carry a surrogate-key header (set by CacheControlPlug, purgeable: true).
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
      tags = conn |> get_resp_header("surrogate-key") |> Enum.flat_map(&String.split/1)
      body = conn.resp_body
      # Write to disk asynchronously so the response is not delayed by the file write.
      Task.start(fn ->
        Bonfire.UI.Common.StaticGenerator.cache_response(url, body, tags: tags)
      end)
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
      # Save original path before StaticGeneratorPlug rewrites request_path to
      # include /index.html — the cache writer needs the unmodified URL.
      # Also mark this connection as eligible for static caching — used by
      # cacheable_response? to decide whether to write the response to disk.
      conn
      |> put_private(:original_request_path, conn.request_path)
      |> put_private(:static_cacheable, true)
      |> Bonfire.UI.Common.StaticGeneratorPlug.make_request_path_static()
    else
      info("do not use cache when signed in")
      conn
    end
  end
end
