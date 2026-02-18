defmodule Bonfire.UI.Common.StaticGeneratorPlug do
  use Plug.Builder
  import Untangle
  use Bonfire.Common.Config

  plug(:make_request_path_static)

  plug(Plug.Static,
    at: "/",
    from: :bonfire
  )

  def make_request_path_static(conn, _ \\ nil)

  def make_request_path_static(%{query_params: %{"cache" => "skip"}} = conn, _) do
    info("skip cache")
    conn
  end

  def make_request_path_static(%{query_params: %{"_format" => format}} = conn, _) do
    # for LVN
    info("skip cache")
    conn
    # do_make_request_path_static(conn, format)
  end

  def make_request_path_static(%{query_params: %{"_email_format" => format}} = conn, _) do
    # for email templates
    do_make_request_path_static(conn, format)
  end

  def make_request_path_static(conn, _) do
    do_make_request_path_static(conn)
  end

  defp do_make_request_path_static(conn, ext \\ "html") do
    filename = "index.#{ext}"

    request_path = conn.request_path || "/"

    #  only generate expired or non-existing caches if on demand mode is enabled (vs for example cron mode)
    with true <- Config.get([__MODULE__, :generate_mode]) == :on_demand,
         %{error: _} <- Bonfire.UI.Common.StaticGenerator.maybe_generate(request_path, ext: ext) do
      error("Could not find or generate a static cache at #{request_path}")
      conn
    else
      _ ->
        static_html_path =
          "#{String.trim_trailing(request_path, "/")}/#{filename}"
          |> info()

        %{
          conn
          | request_path: static_html_path,
            path_info: conn.path_info ++ [filename]
        }
        |> debug
    end
  end
end
