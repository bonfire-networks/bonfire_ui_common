defmodule Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.UI.Common.LiveHandlers

  def call(conn, _) do
    params = e(conn, :params, %{})

    with %{} = assigns <- handle_fallback(e(params, "live_handler", nil), params, conn) do
      conn = (assigns[:conn] || conn)
      locations = Plug.Conn.get_resp_header(conn, "location")
      # |> debug("location")

      if is_list(locations) and length(locations)>0 do
        conn
        |> halt()
      else
        conn
        |> put_view(Bonfire.UI.Common.BasicView)
        |> render("fallback.html", assigns)
      end
    end
  end

  def handle_fallback(action, attrs, conn) do
    # debug(conn)
    with {:noreply, conn} <- LiveHandlers.handle_event(action, attrs, conn, __MODULE__)
    |> debug() do
      msg = get_flash(conn, :error) || get_flash(conn, :info)
      %{conn: conn, title: msg, body: l "This feature usually requires JavaScript, but the app attempted to do what was expected anyway. Did it not work for you? Feedback is welcome! "}
    end
  end
end
