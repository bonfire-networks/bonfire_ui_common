defmodule Bonfire.UI.Common.ErrorController do
  use Bonfire.UI.Common.Web, :controller

  def call(%{params: %{"code" => code}} = conn, _params) do
    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> render("#{code}.html", Map.merge(conn.assigns, conn.params))
  end

  def call(conn, _params) do
    # debug(conn)

    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> render(:app, Map.merge(conn.assigns, conn.params))
  end
end
