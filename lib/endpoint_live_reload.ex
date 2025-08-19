defmodule Bonfire.UI.Common.Endpoint.LiveReload do
  # use Bonfire.Common.Config

  defmacro __using__(code_reloading?) do
    quote do
      def halt_live_reload(%{request_path: "/phoenix/live_reload/socket/websocket"} = conn, _),
        do: conn |> resp(404, "Not enabled") |> halt()

      def halt_live_reload(conn, _), do: conn

      if unquote(code_reloading?) && Application.get_env(:bonfire, :hot_code_reload) &&
           Code.ensure_loaded?(Phoenix.LiveReloader.Socket) do
        socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)

        plug(Phoenix.LiveReloader)
        plug(Phoenix.CodeReloader)

        if unquote(System.get_env("WITH_LV_NATIVE") in ["1", "true", "yes"]) do
          plug LiveViewNative.LiveReloader
        end

        plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :bonfire)

        # FIXME
        # socket "/admin/system/wobserver", Wobserver.Web.PhoenixSocket

        # plug(PhoenixProfiler)
      else
        plug(:halt_live_reload)
      end
    end
  end
end
