defmodule Bonfire.UI.Common.ErrorController do
  use Bonfire.UI.Common.Web, :controller

  def call(conn, params) do
    debug(params)
    debug(conn)

    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> render(:app, conn.assigns)
  end
end
