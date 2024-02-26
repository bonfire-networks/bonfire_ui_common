defmodule Bonfire.UI.Common.ErrorController do
  use Bonfire.UI.Common.Web, :controller

  def call(%{params: %{"code" => "crash"}} = _conn, _params) do
    raise "User triggered error"
  end

  def call(%{params: %{"crash" => code}} = _conn, _params) do
    raise Bonfire.Fail.fail(code)
  end

  def call(%{params: %{"code" => code}} = conn, _params) do
    view_render(conn, "#{code}.html")
  end

  def call(conn, _params) do
    view_render(conn, :app)
  end

  def crash_test(_conn, _params) do
    raise("User-triggered crash")
  end

  def view_render(conn, key) do
    # debug(conn)

    conn
    |> put_view(Bonfire.UI.Common.ErrorView)
    |> put_layout(html: {Bonfire.UI.Common.BasicView, :error})
    |> render(key, Map.merge(conn.assigns, conn.params))
  end
end
