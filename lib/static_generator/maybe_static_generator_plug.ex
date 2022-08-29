defmodule Bonfire.UI.Common.MaybeStaticGeneratorPlug do
  use Plug.Builder
  import Where

  plug :maybe_add_index_html

  plug Plug.Static,
    at: "/",
    from: {:bonfire, "priv/static/#{Bonfire.UI.Common.StaticGenerator.base_path}"}

  # do not serve cache when logged in
  def maybe_add_index_html(%{assigns: %{current_account: %{}}} = conn, _), do: conn
  def maybe_add_index_html(%{assigns: %{current_user: %{}}} = conn, _), do: conn

  def maybe_add_index_html(%{private: %{cache: cache}, assigns: %{}} = conn, _) when cache not in [nil, false] do
    debug(cache, "cache")
    filename = "index.html"
    path_no_slash = String.trim_trailing(conn.request_path, "/")
    # debug(path_no_slash)
    # debug(conn.path_info)
    %{conn |
      request_path: "#{path_no_slash}/#{filename}",
      path_info: conn.path_info ++ [filename]
    }
    # |> debug
  end

  def maybe_add_index_html(conn, _) do
    debug("do not cache")
    conn
  end
end
