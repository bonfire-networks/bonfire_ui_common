defmodule Bonfire.UI.Common.EndpointTemplate do
  use Bonfire.Common.Config

  defmacro __using__(_) do
    ap_base = System.get_env("AP_BASE_PATH", "/pub")

    quote do
      # make sure this comes before the Phoenix endpoint
      use Bonfire.UI.Common.ErrorReportingPlug
      use Bonfire.Common.Settings
      use Bonfire.Common.Localise
      use Untangle
      import Bonfire.Common.Extend
      alias Bonfire.Common.Config
      alias Bonfire.UI.Common.EndpointTemplate
      alias Bonfire.Common.Utils
      import Utils
      alias Bonfire.Common.Types
      alias Bonfire.Common.Extend

      @yes? ~w(true yes 1)
      @no? ~w(false no none 0)

      def log_ip(%{remote_ip: remote_ip} = conn, _) when not is_nil(remote_ip) do
        with {:error, e} <- :inet_parse.ntoa(remote_ip) do
          Logger.error(
            "Request from IP #{inspect(remote_ip)} (failed to parse IP: #{inspect(e)})"
          )
        else
          ip ->
            Logger.info("Request from IP #{ip}")
        end

        conn
      end

      def log_ip(conn, _), do: conn

      def save_url_in_process(%{request_path: request_path} = conn, _)
          when is_binary(request_path) do
        # Save the path in Process dictionary (used by Gettext.POAnnotator)
        Process.put(:bonfire_current_url, request_path)

        conn
      end

      def save_url_in_process(conn, _), do: conn

      # The session copy of the accept header only feeds LiveView content negotiation (RSS/
      # markdown variants of browser pages), so AP/API requests skip the session entirely —
      # fetching + writing it costs cookie decrypt/re-sign crypto on EVERY request, exactly the
      # federation storm path. Same prefix heads as mark_process_context below.
      def save_accept_header(%Plug.Conn{request_path: unquote(ap_base) <> _} = conn, _opts),
        do: conn

      def save_accept_header(%Plug.Conn{request_path: "/.well-known" <> _} = conn, _opts),
        do: conn

      def save_accept_header(%Plug.Conn{request_path: "/api" <> _} = conn, _opts), do: conn

      def save_accept_header(conn, _opts) do
        with [accept_header | _] <- Plug.Conn.get_req_header(conn, "accept"),
             # only for requests ALREADY carrying a session cookie (≈ logged in / mid-auth —
             # the LV-mount negotiation copy is a user feature): never MINTS a cookie for
             # guests (GDPR/caching/the shed plug's presence check), and cookie-less visitors
             # skip even the session fetch (one less cookie HMAC)
             true <- EndpointTemplate.session_cookie?(conn) do
          conn = Plug.Conn.fetch_session(conn)

          # write only on change: a put_session dirties the session → re-signed Set-Cookie
          if Plug.Conn.get_session(conn, :accept_header) != accept_header do
            Plug.Conn.put_session(conn, :accept_header, accept_header)
          else
            conn
          end
        else
          _ -> conn
        end
      end

      # Tags the request process with a coarse `caller_class` (Logger metadata → readable by
      # `Bonfire.Common.Telemetry.StormRecorder`, and on log lines) for storm attribution.
      # Pure path pattern-matching, zero cost. The web_user/web_guest split happens later at
      # LV mount (where current_user is already loaded — no session fetch needed here).
      def mark_process_context(%Plug.Conn{request_path: unquote(ap_base) <> _} = conn, _opts),
        do: put_caller_class(conn, :ap)

      def mark_process_context(%Plug.Conn{request_path: "/.well-known" <> _} = conn, _opts),
        do: put_caller_class(conn, :ap)

      def mark_process_context(%Plug.Conn{request_path: "/api" <> _} = conn, _opts),
        do: put_caller_class(conn, :api)

      def mark_process_context(conn, _opts), do: put_caller_class(conn, :web)

      defp put_caller_class(conn, class) do
        Logger.metadata(caller_class: class)
        conn
      end

      def plug_timing_checkpoint(conn, key) do
        # local read: ServerTimingPlug sets this key in this same request process (a ProcessTree
        # MISS here walked the whole ancestry 5×/request whenever the profiler was off)
        if Process.get(:server_timing_start) do
          Process.put({:server_timing_marker, key}, System.monotonic_time(:microsecond))
        end

        conn
      end

      plug(Bonfire.UI.Common.MultiTenancyPlug)

      use_if_enabled(Absinthe.Phoenix.Endpoint)

      if Application.compile_env(:bonfire, :sql_sandbox, false) do
        plug(Phoenix.Ecto.SQL.Sandbox)
      end

      lv_timeout = String.to_integer(System.get_env("LV_TIMEOUT", "90000"))

      if lv_timeout < 60_000 do
        IO.warn(
          "LV_TIMEOUT (#{lv_timeout}ms) is below 2x the phoenix.js 30s heartbeat interval — idle mobile clients will see abnormal 1006 websocket closes"
        )
      end

      socket("/live", Phoenix.LiveView.Socket,
        websocket: [
          # NOTE: check_origin is set in runtime config instead
          # check_origin: false,
          # check_origin: :conn,
          # whether to enable per message compression on all data frames
          compress: System.get_env("PHX_COMPRESS_LV") not in @no?,
          timeout: lv_timeout,
          # the maximum number of garbage collections before forcing a fullsweep for the socket process. You can set it to 0 to force more frequent clean-ups of your websocket transport processes. (You can also trigger this manually to force garbage collection in the transport process after processing large messages with `send(socket.transport_pid, :garbage_collect)`)
          fullsweep_after: String.to_integer(System.get_env("LV_FULLSWEEP_AFTER", "20")),
          # NOTE: see also `LV_HIBERNATE_AFTER` in the endpoint config
          connect_info: [
            :user_agent,
            # TODO: check if this gives us the "real IP" as set by `RemoteIp`
            :peer_data,
            :x_headers,
            session: EndpointTemplate.session_options()
          ]
        ]
      )

      # Session-less LV socket for cross-origin iframe embeds where the
      # browser blocks the SameSite=Lax session cookie on the WS upgrade.
      # Authentication happens exclusively at LV mount via the
      # `bonfire_embed_token` URL param (see LoadCurrentUserFromEmbedToken).
      # Connect_info deliberately omits `:session` — Phoenix LV only fails with
      # a "stale" reason when `connect_info.session == nil`, not when the key
      # is missing entirely. See deps/phoenix_live_view/lib/phoenix_live_view/channel.ex ~1074.
      socket("/embed_live", Phoenix.LiveView.Socket,
        websocket: [
          compress: System.get_env("PHX_COMPRESS_LV") not in @no?,
          timeout: lv_timeout,
          fullsweep_after: String.to_integer(System.get_env("LV_FULLSWEEP_AFTER", "20")),
          connect_info: [:user_agent, :peer_data, :x_headers]
        ]
      )

      if module_enabled?(Bonfire.API.GraphQL.UserSocket) do
        socket("/api/socket", Bonfire.API.GraphQL.UserSocket,
          websocket: true,
          longpoll: false
        )
      end

      # graphql-transport-ws transport for GraphQL subscriptions (Ferry/graphql-ws clients).
      if Code.ensure_compiled(Bonfire.API.GraphQL.GraphqlWSSocket) ==
           {:module, Bonfire.API.GraphQL.GraphqlWSSocket} and
           module_enabled?(Bonfire.API.GraphQL.GraphqlWSSocket) do
        socket("/api/graphql-ws", Bonfire.API.GraphQL.GraphqlWSSocket,
          websocket: [path: "", subprotocols: ["graphql-transport-ws"]],
          longpoll: false
        )
      end

      if module_enabled?(Bonfire.Notify.Web.MastoStreamingWebSocket) do
        socket("/api/v1", Bonfire.Notify.Web.MastoStreamingWebSocket,
          websocket: [
            path: "streaming",
            check_origin: false,
            timeout: 120_000,
            connect_info: [:peer_data, :x_headers, :sec_websocket_headers]
          ]
        )
      end

      # Serve at "/" the static files from "priv/static" directory.
      #
      # In production: serve gzip, cache non-versioned files for 1 day
      # In dev: no gzip (stale .gz files cause hard-to-debug issues), no caching (max-age=0)
      is_prod = Config.env() == :prod
      serve_gzip = is_prod

      # Fingerprinted assets (Phoenix appends ?vsn=d) — default: 1 year in prod, 0 in dev
      # (in dev the vsn marker is static "d" and doesn't change on file edits, so immutable caching
      # would prevent updated CSS/images from reaching the browser until a hard reload).
      # Override (at compile time) with CACHE_STATIC_VSN_MAX_AGE (seconds).
      default_vsn_max_age = if is_prod, do: "#{div(to_timeout(week: 52), 1_000)}", else: "0"

      vsn_max_age =
        String.to_integer(System.get_env("CACHE_STATIC_VSN_MAX_AGE", default_vsn_max_age))

      # Non-versioned files — in dev: no caching (0s), in prod: 1 day
      # Override (at compile time) with CACHE_STATIC_ETAG_MAX_AGE (seconds)
      default_etag_max_age = if is_prod, do: "#{div(to_timeout(day: 1), 1_000)}", else: "0"

      etag_max_age =
        String.to_integer(System.get_env("CACHE_STATIC_ETAG_MAX_AGE", default_etag_max_age))

      cache_control_for_vsn_requests = "public, max-age=#{vsn_max_age}, immutable"
      cache_control_for_etags = "public, max-age=#{etag_max_age}"

      plug(Plug.Static,
        at: "/",
        from: :bonfire_ui_common,
        gzip: serve_gzip,
        cache_control_for_vsn_requests: cache_control_for_vsn_requests,
        cache_control_for_etags: cache_control_for_etags,
        only: Bonfire.UI.Common.Web.static_paths()
      )

      plug(Plug.Static,
        at: "/",
        from: :bonfire,
        gzip: serve_gzip,
        cache_control_for_vsn_requests: cache_control_for_vsn_requests,
        cache_control_for_etags: cache_control_for_etags,
        only: Bonfire.UI.Common.Web.static_paths()
      )

      plug(Plug.Static,
        at: "/data/uploads/",
        from: "data/uploads",
        gzip: serve_gzip
      )

      # Serve static files from the current flavour's OTP app (e.g. jacobin fonts)
      flavour_otp_app = Bonfire.Common.Config.top_level_otp_app()

      flavour_static =
        if flavour_otp_app not in [:bonfire, :bonfire_ui_common, :bonfire_common] do
          try do
            Application.app_dir(flavour_otp_app, "priv/static")
          rescue
            _ ->
              path = "extensions/#{flavour_otp_app}/priv/static"
              if File.dir?(path), do: path
          end
        end

      if flavour_static do
        plug(Plug.Static,
          at: "/",
          from: flavour_static,
          gzip: serve_gzip,
          cache_control_for_vsn_requests: cache_control_for_vsn_requests,
          cache_control_for_etags: cache_control_for_etags,
          only: Bonfire.UI.Common.Web.static_paths()
        )
      end

      if System.get_env("LIVE_DASHBOARD_LOGGER") == "true" do
        plug(Phoenix.LiveDashboard.RequestLogger,
          param_key: "request_logger",
          cookie_key: "request_logger"
        )
      end

      plug(Plug.RequestId)

      # parses real IP in conn if behind proxy
      plug(RemoteIp)

      plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

      # Server-Timing headers for browser DevTools + Page Profiler dashboard (only when PAGE_PROFILER_ENABLED=true)
      # Placed early to capture prod-relevant plugs (Parsers, Session, CORS, etc.) in the "plugs" metric
      plug(Bonfire.UI.Common.ServerTimingPlug)

      if extension_enabled?(:bonfire_analytics) do
        plug PhoenixAnalytics.Plugs.RequestTracker
      end

      plug Bonfire.UI.Common.MaybePlausibleProxyPlug

      plug :save_url_in_process
      plug :log_ip

      # NOTE: configured in Bonfire.UI.Common.RuntimeConfig
      plug CORSPlug,
        origin: &Bonfire.UI.Common.EndpointTemplate.cors_origin/1,
        headers: ["*"]

      if System.get_env("TIDEWAVE_ENABLED") not in ["false", "0", "no"] and
           Code.ensure_loaded?(Tidewave) do
        # FIXME: remote access should be disabled but it's not working locally without for now
        plug Tidewave, allow_remote_access: true
      end

      @parser_opts [
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library(),
        # Flavours can override to stash the raw body for signed-webhook
        # verification (e.g. Jacobin points this at `Bonfire.Ghost.BodyReader`).
        # Default keeps ActivityPub HTTP-signature digest computation intact.
        body_reader:
          Application.compile_env(
            :bonfire_ui_common,
            :body_reader,
            {ActivityPub.Web.Plugs.DigestPlug, :read_body, []}
          )
      ]
      # @opts Plug.Parsers.init(@parser_opts)
      # @decorate time()
      # defp parsers(conn, _), do: Plug.Parsers.call(conn, @opts)
      # plug :parsers
      plug :plug_timing_checkpoint, :before_parsers
      plug(Plug.Parsers, @parser_opts)
      plug :plug_timing_checkpoint, :after_parsers

      plug(Bonfire.UI.Common.ErrorReportingPlug)

      plug(Plug.MethodOverride)
      plug(Plug.Head)
      plug :plug_timing_checkpoint, :before_session
      plug(Plug.Session, EndpointTemplate.session_options())
      plug :plug_timing_checkpoint, :after_session

      plug :save_accept_header

      # after the session plug so guest-vs-user is readable from the cookie (no DB)
      plug :mark_process_context

      # reads the caller_class set just above; sheds BEFORE the router (and thus before
      # HTTP-signature crypto) when Overload reports :hard, near-free when calm
      plug(Bonfire.UI.Common.OverloadShedPlug)

      def include_assets(conn) do
        include_assets(conn, :top)
        include_assets(conn, :bottom)
      end

      def include_assets(conn, :top) do
        endpoint_module = Bonfire.Common.Config.endpoint_module()

        {font_name, font_href} =
          Bonfire.UI.Common.FontHelper.font_for(current_user: current_user(conn))

        # Override x-cloak CSS for tests to ensure hidden elements are visible
        x_cloak_override =
          if Config.env() == :test do
            """
            <style>
              @layer utilities {
                [x-cloak] { display: block !important; }
              }
            </style>
            """
          else
            ""
          end

        plausible_script =
          with config when is_list(config) <-
                 Application.get_env(:bonfire_ui_common, :plausible_proxy, []),
               true <- config[:enabled] == true do
            domain = config[:domain] || Bonfire.Common.URIs.base_domain()
            path = config[:local_path] || "/js/plausible_script.js"
            ~s(<script defer data-domain="#{domain}" src="#{path}"></script>)
          else
            _ -> ""
          end

        """
        <link rel="icon" type="image/x-icon" href="/favicon.ico">
        <link rel="icon" type="image/svg+xml" href='#{endpoint_module.static_path("/images/bonfire-icon.svg")}'>
        <link rel="icon" type="image/svg+xml" data-dynamic-href="{svg}">

        <link phx-track-static rel='stylesheet' href='#{endpoint_module.static_path("/assets/bonfire_basic.css")}'/>
        <link data-font phx-track-static rel='stylesheet' href='#{font_href}'/>
        <style>:root { --font-sans: "#{font_name}", ui-sans-serif, system-ui, sans-serif; }</style>

        #{x_cloak_override}

        #{plausible_script}

        #{if Extend.module_enabled?(PhoenixGon.View), do: PhoenixGon.View.render_gon_script(conn) |> Phoenix.HTML.safe_to_string()}

        <link rel="manifest" href="/pwa/manifest.json" />

        <!-- PWA iOS support -->
        <meta name="mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
        <meta name="apple-mobile-web-app-title" content="Bonfire">
        <link rel="apple-touch-icon" href="/pwa/ios/180.png">

        <!-- iOS Splash Screens (home-screen PWA launch only).
             iOS requires the image's pixel size to EXACTLY equal
             device-width x device-height x device-pixel-ratio, or it is silently ignored —
             hence one image per screen geometry, named splash-<pixelWxpixelH>.png. -->
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-750x1334.png" media="(device-width: 375px) and (device-height: 667px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-828x1792.png" media="(device-width: 414px) and (device-height: 896px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1125x2436.png" media="(device-width: 375px) and (device-height: 812px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1242x2688.png" media="(device-width: 414px) and (device-height: 896px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1170x2532.png" media="(device-width: 390px) and (device-height: 844px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1284x2778.png" media="(device-width: 428px) and (device-height: 926px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1179x2556.png" media="(device-width: 393px) and (device-height: 852px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1290x2796.png" media="(device-width: 430px) and (device-height: 932px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1206x2622.png" media="(device-width: 402px) and (device-height: 874px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1320x2868.png" media="(device-width: 440px) and (device-height: 956px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1536x2048.png" media="(device-width: 768px) and (device-height: 1024px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1640x2360.png" media="(device-width: 820px) and (device-height: 1180px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-1668x2388.png" media="(device-width: 834px) and (device-height: 1194px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/splash-2048x2732.png" media="(device-width: 1024px) and (device-height: 1366px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">

        <!-- Browser/PWA chrome color — must stay in sync with theme_color and
             background_color in pwa/manifest.json -->
        <meta name="theme-color" content="#191e25">
        <meta name="msapplication-navbutton-color" content="#191e25">
        <meta name="msapplication-TileColor" content="#191e25">
        <!-- No PWA update prompt needed: the SW calls skipWaiting() so new versions
             activate immediately, HTML is never SW-cached, asset URLs are content-hashed,
             and LiveView's phx-track-static already triggers a reload when tracked
             assets change after a deploy. -->
        """
      end

      def include_assets(%{assigns: assigns} = conn, :bottom) do
        endpoint_module = Bonfire.Common.Config.endpoint_module()
        current_user_id = Utils.current_user_id(assigns)
        embed_authed = conn.private[:bonfire_embed_token_authed] == true

        live_socket? =
          assigns[:force_live] || (current_user_id && !assigns[:force_static]) || embed_authed

        # || Utils.current_account(assigns)

        js_path =
          if live_socket? || (current_user_id && !assigns[:force_static]) do
            endpoint_module.static_path("/assets/bonfire_live.js")
          else
            endpoint_module.static_path("/assets/bonfire_basic.js")
          end

        # In dev, append file mtime as cache buster to avoid stale memory-cached scripts
        js =
          if Config.env() != :prod do
            mtime =
              Path.join(:code.priv_dir(:bonfire) |> to_string(), "static" <> js_path)
              |> File.stat()
              |> case do
                {:ok, %{mtime: mtime}} -> :erlang.phash2(mtime)
                _ -> System.system_time(:second)
              end

            "#{js_path}?v=#{mtime}"
          else
            js_path
          end

        """
        <script data-live-socket="#{live_socket? || "false"}" defer phx-track-static crossorigin='anonymous' src='#{js}'></script>
        <link phx-track-static rel='stylesheet' href='#{endpoint_module.static_path("/images/icons/icons.css")}'/>
        """
      end

      def node_name do
        Node.self()
      end

      def reload!(opts \\ ["--no-all-warnings"]),
        do: Phoenix.CodeReloader.reload!(__MODULE__, opts)
    end
  end

  @doc """
  Whether the request PRESENTED a session cookie: a free header check, no fetch/HMAC.

  Since guests are kept cookieless (see `Bonfire.UI.Common.session_logged_in?/1`), cookie
  presence ≈ logged in (or mid-auth flow), used by the overload shed plug's guest tier and to
  gate session writes like `save_accept_header` so they never MINT a cookie.
  """
  def session_cookie?(conn) do
    key = Keyword.get(session_options(), :key, "_bonfire_key")

    conn
    |> Plug.Conn.get_req_header("cookie")
    |> Enum.any?(&String.contains?(&1, key))
  end

  def session_options do
    # TODO: check that this is changeable at runtime
    # The session will be stored in the cookie and signed,
    # this means its contents can be read but not tampered with.
    # Set :encryption_salt if you would also like to encrypt it.
    [
      store: :cookie,
      key: "_bonfire_key",
      secure: System.get_env("PUBLIC_PORT") == "443",
      signing_salt: Config.get!(:signing_salt),
      encryption_salt: Config.get!(:encryption_salt),
      max_age: Config.get(:session_time_to_remember, div(to_timeout(day: 60), 1_000))
    ]
  end

  def cors_origin(conn) do
    # NOTE: configured in Bonfire.UI.Common.RuntimeConfig
    cors_routes =
      Application.get_env(:bonfire_ui_common, :cors_routes) || []

    path = conn.request_path

    Enum.find_value(cors_routes, [], fn
      %{paths: prefixes, origins: origins} when is_list(prefixes) ->
        if Enum.any?(prefixes, &String.starts_with?(path, &1)), do: origins

      %{paths: prefix, origins: origins} when is_binary(prefix) ->
        if String.starts_with?(path, prefix), do: origins

      _ ->
        []
    end) || []
  end
end
