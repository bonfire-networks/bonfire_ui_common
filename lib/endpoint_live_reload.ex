defmodule Bonfire.UI.Common.Endpoint.LiveReload do
  # alias Bonfire.Common.Config

  defmacro __using__(code_reloading?) do
    quote do
      def halt_live_reload(%{request_path: "/phoenix/live_reload/socket/websocket"} = conn, _),
        do: conn |> resp(404, "Not enabled") |> halt()

      def halt_live_reload(conn, _), do: conn

      # Code reloading can be explicitly enabled under the
      # :code_reloader configuration of your endpoint.
      if Application.compile_env(:bonfire, :hot_code_reload) && unquote(code_reloading?) && Code.ensure_loaded?(Phoenix.LiveReloader.Socket) do
        socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
        plug(Phoenix.LiveReloader)
        plug(Phoenix.CodeReloader)

        if unquote(System.get_env("WITH_LV_NATIVE") in ["1", "true"]) do
          plug LiveViewNative.LiveReloader
        end

        plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :bonfire_umbrella)

        # FIXME
        # socket "/admin/system/wobserver", Wobserver.Web.PhoenixSocket

        # plug(PhoenixProfiler)
      else
        plug(:halt_live_reload)
      end
    end
  end
end
