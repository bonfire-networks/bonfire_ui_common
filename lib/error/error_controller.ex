defmodule Bonfire.UI.Common.ErrorController do
  use Bonfire.UI.Common.Web, :controller

  def call(%{params: %{"code" => "crash"}} = conn, _params) do
    raise "User triggered error"
  end

  def call(%{params: %{"crash" => code}} = conn, _params) do
    raise Bonfire.Fail.fail(code)
  end

  def call(%{params: %{"code" => code}} = conn, _params) do
    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> put_layout(html: {Bonfire.UI.Common.BasicView, :error})
    |> render("#{code}.html", Map.merge(conn.assigns, conn.params))
  end

  def call(conn, _params) do
    # debug(conn)

    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> put_layout(html: {Bonfire.UI.Common.BasicView, :error})
    |> render(:app, Map.merge(conn.assigns, conn.params))
  end
end
