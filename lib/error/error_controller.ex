defmodule Bonfire.UI.Common.ErrorController do
  use Bonfire.UI.Common.Web, :controller

  def call(conn, _params) do
    # debug(get_flash(conn)) # TODO

    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> render(:app, conn.assigns)
  end
end
