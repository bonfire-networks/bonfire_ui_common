defmodule Bonfire.UI.Common.StaticGeneratorPlug do
  use Plug.Builder
  import Untangle
  alias Bonfire.Common.Config

  plug(:make_request_path_static)

  plug(Plug.Static,
    at: "/",
    from: :bonfire
  )

  def make_request_path_static(conn, _ \\ nil)

  def make_request_path_static(%{query_params: %{"cache" => "skip"}} = conn, _) do
    debug("skip cache")
    conn
  end

  def make_request_path_static(conn, _) do
    filename = "index.html"

    request_path = conn.request_path || "/"

    #  only generate expired or non-existing caches if on demand mode is enabled (vs for example cron mode)
    with true <- Config.get([__MODULE__, :generate_mode]) == :on_demand,
         %{error: _} <- Bonfire.UI.Common.StaticGenerator.maybe_generate(request_path) do
      error("Could not find or generate a static cache at #{request_path}")
      conn
    else
      _ ->
        static_html_path =
          "#{String.trim_trailing(request_path, "/")}/#{filename}"
          |> debug()

        %{
          conn
          | request_path: static_html_path,
            path_info: conn.path_info ++ [filename]
        }
        |> debug
    end
  end
end
