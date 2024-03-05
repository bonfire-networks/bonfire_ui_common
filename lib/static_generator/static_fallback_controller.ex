defmodule Bonfire.UI.Common.StaticFallbackController do
  use Bonfire.UI.Common.Web, :controller

  def fallback(conn, %{"path" => path} = _params) do
    url = Path.join(["/"] ++ List.wrap(path))
    info(url, "static page does not yet exist")

    with %{error: _} <- Bonfire.UI.Common.StaticGenerator.generate(url) do
      error(url, "Could not generate static file")

      conn
      |> send_resp(404, "Page not found")
      |> halt()
    else
      _ ->
        public_url = Path.join(["/", Bonfire.UI.Common.StaticGenerator.base_path(), url])

        info(
          public_url,
          "static page was generated, now serving the static assets at this URL"
        )

        conn
        |> redirect_to(public_url)
        |> halt()
    end
  end

  def fallback(conn, _params) do
    error("static page does not exist")

    conn
    |> send_resp(404, "Page not found")
    |> halt()
  end
end
