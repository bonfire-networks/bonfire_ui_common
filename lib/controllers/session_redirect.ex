defmodule Bonfire.UI.Common.SessionRedirectController do
  use Bonfire.UI.Common.Web, :controller

  def set_and_redirect(conn, params) do
    Enum.reduce(params, conn, fn {key, val}, conn ->
      store(conn, key, val)
    end)
    |> redirect_to(params["to"])
  end

  defp store(conn, key, val) do
    debug(key, "key")
    debug(val, "val")
    conn
    |> put_session(key, val)
  end
end
