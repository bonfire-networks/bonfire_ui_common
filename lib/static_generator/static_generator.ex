defmodule Bonfire.UI.Common.StaticGenerator do
  @moduledoc """
  Static-site generator which can take a list of URLs served by the current Phoenix server and output static HTML for them
  """
  # import Plug.Conn
  import Phoenix.ConnTest
  import Untangle
  alias Bonfire.Common.Config

  @endpoint Config.get(:endpoint_module, Bonfire.Web.Endpoint)

  def base_path, do: "public"

  defp static_dir() do
    src = Path.join(["priv", "static", base_path()])
    src <> "/"
  end

  def generate(urls, opts \\ [])

  def generate(urls, opts) when is_list(urls) do
    conn = Phoenix.ConnTest.build_conn()

    dest =
      Application.app_dir(
        Config.get(:umbrella_otp_app, :bonfire),
        opts[:output_dir] || Config.get([__MODULE__, :output_dir]) ||
          static_dir()
      )
      |> debug("output_dir")

    maybe_clean_and_copy_assets(dest, opts)

    urls
    |> Enum.map(fn url -> generate_html(conn, url) end)
    |> debug()
    |> Enum.map(fn
      {:error, e} -> {:error, e}
      {url, content} -> write_file(url, content, dest)
    end)
    |> debug()
  end

  def generate(url, opts) do
    with [ok: _] <- generate([url], opts) do
      :ok
    end
  end

  defp generate_html(conn, url) do
    with html when is_binary(html) <- html_response(get(conn, url), 200) do
      {url, html}
    else
      e ->
        {:error, e}
    end
  end

  defp write_file(path, content, dest) do
    full_path = Path.join([dest, path, "index.html"])
    dirname = Path.dirname(full_path)

    with :ok <- File.mkdir_p(dirname),
         :ok <- File.write(full_path, content) do
      {:ok, path}
    else
      _ -> {:error, path}
    end
  end

  defp maybe_clean_and_copy_assets(dest, opts) do
    if opts[:first_delete_output_dir], do: clean_files(dest)
    if opts[:copy_static_assets], do: copy_assets(static_dir(), dest)
  end

  defp clean_files(dest) do
    with {:ok, _} <- File.rm_rf(dest) do
      :ok
    else
      error -> error(error)
    end
  end

  defp copy_assets(src, dest) do
    pars = ["-r", src, dest]

    with {_out, 0} <- System.cmd("rsync", pars) do
      :ok
    else
      error -> error(error)
    end
  end
end
