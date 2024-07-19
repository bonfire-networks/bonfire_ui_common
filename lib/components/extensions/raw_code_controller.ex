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

    path_str = Path.join(path)

    with {:ok, raw} <- Bonfire.Common.Extend.file_code(path_str) do
      # public_url = Path.join(["/", Bonfire.UI.Common.StaticGenerator.base_path(), url])

      raw = Bonfire.Common.Extend.return_file(raw)

      conn
      |> put_resp_content_type(
        MIME.from_path(path_str) || cond do
          String.ends_with?(path_str, ".js") -> "text/javascript"
          String.ends_with?(path_str, ".css") -> "text/css"
          String.ends_with?(path_str, ".html") -> "text/html"
          String.ends_with?(path_str, [".woff", ".woff2"]) -> "application/x-font-woff"
          is_binary(raw) -> "text/plain"
          true -> "application/octet-stream"
        end
      )
      |> Plug.Conn.send_resp(200, raw)
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
