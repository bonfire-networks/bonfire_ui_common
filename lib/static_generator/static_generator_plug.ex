defmodule Bonfire.UI.Common.StaticGeneratorPlug do
  use Plug.Builder
  import Where

  plug :add_index_html

  plug Plug.Static,
    at: "/",
    from: :bonfire

  def add_index_html(conn, _) do
    filename = "index.html"
    path_no_slash = String.trim_trailing(conn.request_path, "/")
    debug(path_no_slash)
    # debug(conn.path_info)
    %{conn |
      request_path: "#{path_no_slash}/#{filename}",
      path_info: conn.path_info ++ [filename]
    }
    # |> debug
  end
end
