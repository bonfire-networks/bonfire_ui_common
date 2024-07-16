defmodule Bonfire.UI.Common.RawCodeController do
  use Bonfire.UI.Common.Web, :controller

  def docs(conn, %{"path" => path} = params) do
    code(conn, Map.put(params, "path", ["docs", "exdoc"] ++ path))
  end

  def docs(conn, _params) do
    conn
    |> send_resp(404, "Docs not found")
    |> halt()
  end

  def code(conn, %{"path" => path} = params) do
    # url = Path.join(["/"] ++ List.wrap(path))
    debug(path)

    with {:ok, code} <- Bonfire.Common.Extend.file_code(Path.join(path)) do
      # public_url = Path.join(["/", Bonfire.UI.Common.StaticGenerator.base_path(), url])

      conn
      |> Plug.Conn.send_resp(200, code)
      |> halt()
    else
      _ ->
        if List.last(path) != "index.html" do
          code(conn, Map.put(params, "path", path ++ ["index.html"]))
        else
          conn
          |> send_resp(404, "File not found")
          |> halt()
        end
    end
  end

  def code(conn, _params) do
    conn
    |> send_resp(404, "File not found")
    |> halt()
  end
end
