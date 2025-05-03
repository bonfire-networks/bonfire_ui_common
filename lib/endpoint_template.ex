defmodule Bonfire.UI.Common.EndpointTemplate do
  use Bonfire.Common.Config

  defmacro __using__(_) do
    quote do
      # make sure this comes before the Phoenix endpoint
      use Bonfire.UI.Common.ErrorReportingPlug
      use Bonfire.Common.Settings
      use Untangle
      import Bonfire.Common.Extend
      alias Bonfire.UI.Common.EndpointTemplate
      alias Bonfire.Common.Utils
      alias Bonfire.Common.Types
      alias Bonfire.Common.Extend

      def log_ip(%{remote_ip: remote_ip} = conn, _) when not is_nil(remote_ip) do
        Logger.info("Request from #{:inet_parse.ntoa(remote_ip)}")

        conn
      end

      def log_ip(conn, _), do: conn

      plug(Bonfire.UI.Common.MultiTenancyPlug)

      use_if_enabled(Absinthe.Phoenix.Endpoint)

      if Application.compile_env(:bonfire, :sql_sandbox) do
        plug(Phoenix.Ecto.SQL.Sandbox)
      end

      socket("/live", Phoenix.LiveView.Socket,
        websocket: [
          check_origin: false,
          # check_origin: :conn,
          # whether to enable per message compression on all data frames
          compress: false,
          # the timeout for keeping websocket connections open after it last received data, usually defaults to 60_000ms (1 minute)
          timeout: String.to_integer(System.get_env("LV_TIMEOUT", "42000")),
          # the maximum number of garbage collections before forcing a fullsweep for the socket process. You can set it to 0 to force more frequent clean-ups of your websocket transport processes. (You can also trigger this manually to force garbage collection in the transport process after processing large messages with `send(socket.transport_pid, :garbage_collect)`)
          fullsweep_after: String.to_integer(System.get_env("LV_FULLSWEEP_AFTER", "20")),
          # NOTE: see also `LV_HIBERNATE_AFTER` in the endpoint config 
          connect_info: [
            :user_agent,
            # TODO: check if this gives us the "real IP" as set by `RemoteIp`
            :peer_data,
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
      plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

      # parses real IP in conn if behind proxy
      plug(RemoteIp)
      plug :log_ip

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

      def include_assets(conn) do
        include_assets(conn, :top)
        include_assets(conn, :bottom)
      end

      def include_assets(conn, :top) do
        endpoint_module = Bonfire.Common.Config.endpoint_module()

        font_family =
          Bonfire.Common.Settings.get([:ui, :font_family], "Inter (Latin Languages)", conn)
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

        """
        <link rel="icon" type="image/x-icon" href="/favicon.ico">
        <link rel="icon" type="image/svg+xml" href='#{endpoint_module.static_path("/images/bonfire-icon.svg")}'>
        <link rel="icon" type="image/svg+xml" data-dynamic-href="{svg}">

        <link phx-track-static rel='stylesheet' href='#{endpoint_module.static_path("/assets/bonfire_basic.css")}'/>
        <link phx-track-static rel='stylesheet' href='#{endpoint_module.static_path("/fonts/#{font_family}.css")}'/>

        <script defer phx-track-static crossorigin='anonymous' src='#{endpoint_module.static_path("/images/icons/svg-inject.min.js")}'></script>

        #{if Extend.module_enabled?(PhoenixGon.View), do: PhoenixGon.View.render_gon_script(conn) |> Phoenix.HTML.safe_to_string()}

        <link rel="manifest" href="/pwa/manifest.json" /> 
        <!-- TODO: move to JS hook?
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

        js =
          if assigns[:force_live] || Utils.current_user(assigns) do
            # || Utils.current_account(assigns)
            endpoint_module.static_path("/assets/bonfire_live.js")
          else
            endpoint_module.static_path("/assets/bonfire_basic.js")
          end

        """
        <script defer phx-track-static crossorigin='anonymous' src='#{js}'></script>
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
end
