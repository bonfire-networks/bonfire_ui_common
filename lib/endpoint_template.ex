defmodule Bonfire.UI.Common.EndpointTemplate do
  use Bonfire.Common.Config

  defmacro __using__(_) do
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
      @no? ~w(false no 0)

      def log_ip(%{remote_ip: remote_ip} = conn, _) when not is_nil(remote_ip) do
        with {:error, e} <- :inet.parse_ntoa(remote_ip) do
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

      def save_accept_header(conn, _opts) do
        case Plug.Conn.get_req_header(conn, "accept") do
          [accept_header | _] ->
            conn
            |> Plug.Conn.fetch_session()
            |> Plug.Conn.put_session(:accept_header, accept_header)

          [] ->
            conn
        end
      end

      plug(Bonfire.UI.Common.MultiTenancyPlug)

      use_if_enabled(Absinthe.Phoenix.Endpoint)

      if Application.compile_env(:bonfire, :sql_sandbox, false) do
        plug(Phoenix.Ecto.SQL.Sandbox)
      end

      socket("/live", Phoenix.LiveView.Socket,
        websocket: [
          check_origin: false,
          # check_origin: :conn,
          # whether to enable per message compression on all data frames
          compress: System.get_env("PHX_COMPRESS_LV") not in @no?,
          # the timeout for keeping websocket connections open after it last received data, usually defaults to 60_000ms (1 minute)
          timeout: String.to_integer(System.get_env("LV_TIMEOUT", "42000")),
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

      if module_enabled?(Bonfire.API.GraphQL.UserSocket) do
        socket("/api/socket", Bonfire.API.GraphQL.UserSocket,
          websocket: true,
          longpoll: false
        )
      end

      # Serve at "/" the static files from "priv/static" directory.
      #
      # You should set gzip to true if you are running phx.digest
      # when deploying your static files in production.

      plug(Plug.Static,
        at: "/",
        from: :bonfire_ui_common,
        gzip: true,
        only: Bonfire.UI.Common.Web.static_paths()
      )

      plug(Plug.Static,
        at: "/",
        from: :bonfire,
        gzip: true,
        only: Bonfire.UI.Common.Web.static_paths()
      )

      plug(Plug.Static,
        at: "/data/uploads/",
        from: "data/uploads",
        gzip: true
      )

      # plug(Plug.Static,
      #   at: "/",
      #   from: :livebook,
      #   gzip: true,
      #   only: ~w(images js)
      # )

      # plug(Plug.Static,
      #   at: "/livebook/",
      #   from: :livebook,
      #   gzip: true,
      #   only: ~w(css images js favicon.ico robots.txt cache_manifest.json)
      # )

      # TODO: serve priv/static from any extensions that have one as well?

      plug(Phoenix.LiveDashboard.RequestLogger,
        param_key: "request_logger",
        cookie_key: "request_logger"
      )

      plug(Plug.RequestId)

      # parses real IP in conn if behind proxy
      plug(RemoteIp)

      plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

      if extension_enabled?(:bonfire_analytics) do
        plug PhoenixAnalytics.Plugs.RequestTracker
      end

      plug :save_url_in_process
      plug :log_ip

      # NOTE: configured in Bonfire.UI.Common.RuntimeConfig
      plug CORSPlug, origin: &Bonfire.UI.Common.EndpointTemplate.cors_origin/1

      if System.get_env("TIDEWAVE_ENABLED") not in ["false", "0", "no"] and
           Code.ensure_loaded?(Tidewave) do
        # FIXME: remote access should be disabled but it's not working locally without for now
        plug Tidewave, allow_remote_access: true
      end

      @parser_opts [
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library(),
        # TODO: only include if AP lib is available/enabled
        body_reader: {ActivityPub.Web.Plugs.DigestPlug, :read_body, []}
      ]
      # @opts Plug.Parsers.init(@parser_opts)
      # @decorate time()
      # defp parsers(conn, _), do: Plug.Parsers.call(conn, @opts)
      # plug :parsers
      plug(Plug.Parsers, @parser_opts)

      plug(Bonfire.UI.Common.ErrorReportingPlug)

      plug(Plug.MethodOverride)
      plug(Plug.Head)
      plug(Plug.Session, EndpointTemplate.session_options())

      plug :save_accept_header

      def include_assets(conn) do
        include_assets(conn, :top)
        include_assets(conn, :bottom)
      end

      def include_assets(conn, :top) do
        endpoint_module = Bonfire.Common.Config.endpoint_module()

        font_family =
          Bonfire.Common.Settings.get(
            [:ui, :font_family],
            "Inter (Latin Languages)",
            current_user: current_user(conn),
            name: l("Font"),
            description: l("Default font to use throughout the interface.")
          )
          |> Types.maybe_to_string()
          |> String.trim_trailing(" Languages)")
          |> String.replace([" ", "-", "(", ")"], "-")
          |> String.replace("--", "-")
          |> String.downcase()

        # unused?
        # <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/choices.js/public/assets/styles/choices.min.css" />
        # <script src="https://cdn.jsdelivr.net/npm/choices.js/public/assets/scripts/choices.min.js"></script>

        # imported into main CSS already
        # <link href="https://unpkg.com/@yaireo/tagify/dist/tagify.css" rel="stylesheet" type="text/css" />

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

        """
        <link rel="icon" type="image/x-icon" href="/favicon.ico">
        <link rel="icon" type="image/svg+xml" href='#{endpoint_module.static_path("/images/bonfire-icon.svg")}'>
        <link rel="icon" type="image/svg+xml" data-dynamic-href="{svg}">

        <link phx-track-static rel='stylesheet' href='#{endpoint_module.static_path("/assets/bonfire_basic.css")}'/>
        <link phx-track-static rel='stylesheet' href='#{endpoint_module.static_path("/fonts/#{font_family}.css")}'/>

        #{x_cloak_override}

        #{if Extend.module_enabled?(PhoenixGon.View), do: PhoenixGon.View.render_gon_script(conn) |> Phoenix.HTML.safe_to_string()}

        <link rel="manifest" href="/pwa/manifest.json" />

        <!-- PWA iOS support -->
        <meta name="mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
        <meta name="apple-mobile-web-app-title" content="Bonfire">
        <link rel="apple-touch-icon" href="/pwa/ios/180.png">

        <!-- iOS Splash Screens -->
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-15-splash.png" media="(device-width: 393px) and (device-height: 852px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-15-plus-splash.png" media="(device-width: 430px) and (device-height: 932px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-15-pro-max-splash.png" media="(device-width: 430px) and (device-height: 932px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-x-splash.png" media="(device-width: 375px) and (device-height: 812px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-xs-max-splash.png" media="(device-width: 414px) and (device-height: 896px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-xr-splash.png" media="(device-width: 414px) and (device-height: 896px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-12-splash.png" media="(device-width: 390px) and (device-height: 844px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/iphone-12-pro-max-splash.png" media="(device-width: 428px) and (device-height: 926px) and (-webkit-device-pixel-ratio: 3) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/ipad-splash.png" media="(device-width: 768px) and (device-height: 1024px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/ipad-pro-11-splash.png" media="(device-width: 834px) and (device-height: 1194px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">
        <link rel="apple-touch-startup-image" href="/pwa/ios/splash/ipad-pro-12.9-splash.png" media="(device-width: 1024px) and (device-height: 1366px) and (-webkit-device-pixel-ratio: 2) and (orientation: portrait)">

        <!-- Android PWA theme and background -->
        <meta name="msapplication-navbutton-color" content="#191e25">
        <meta name="msapplication-TileColor" content="#191e25">
        <!-- PWA Update Prompt - TODO: move to JS hook?
        <script type="module">
          import '@pwabuilder/pwaupdate';
          const el = document.createElement('pwa-update');
          document.body.appendChild(el);
        </script>
        -->
        """
      end

      def include_assets(%{assigns: assigns} = _conn, :bottom) do
        endpoint_module = Bonfire.Common.Config.endpoint_module()
        current_user_id = Utils.current_user_id(assigns)

        live_socket? = assigns[:force_live] || (current_user_id && !assigns[:force_static])
        # || Utils.current_account(assigns)

        js =
          if live_socket? || current_user_id do
            endpoint_module.static_path("/assets/bonfire_live.js")
          else
            endpoint_module.static_path("/assets/bonfire_basic.js")
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
      # 60 days by default
      max_age: Config.get(:session_time_to_remember, 60 * 60 * 24 * 60)
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
