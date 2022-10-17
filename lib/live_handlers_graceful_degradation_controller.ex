defmodule Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.UI.Common.LiveHandlers

  def call(%{params: params} = conn, _) do
    with %{} = assigns <-
           handle_fallback(handler_from_params(params), params, conn) do
      conn = assigns[:conn] || conn
      locations = Plug.Conn.get_resp_header(conn, "location")

      if is_list(locations) and length(locations) > 0 do
        halt(conn)
      else
        conn
        |> put_view(Bonfire.UI.Common.BasicView)
        |> render("fallback.html", assigns)
      end
    end
  end

  defp handler_from_params(%{"live_handler" => module, "action" => action})
       when is_binary(action) do
    {module, action}
  end

  defp handler_from_params(%{"live_handler" => module}) do
    module
  end

  defp handle_fallback(action, attrs, conn) do
    # debug(conn)
    with {:noreply, conn} <-
           LiveHandlers.handle_event(action, attrs, conn, __MODULE__)
           |> debug() do
      msg = get_flash(conn, :error) || get_flash(conn, :info)

      %{
        conn: conn,
        title: msg,
        body:
          l(
            "This feature usually requires JavaScript, but the app attempted to do what was expected anyway. Did it not work for you? Feedback is welcome! "
          )
      }
    end
  end
end
