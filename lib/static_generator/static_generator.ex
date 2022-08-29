
defmodule Bonfire.UI.Common.StaticGenerator do
  @moduledoc """
  Static-site generator which can take a list of URLs served by the current Phoenix server and output static HTML for them
  """
  use Phoenix.ConnTest
  import Where
  alias Bonfire.Common.Config

  @endpoint Config.get(:endpoint_module, Bonfire.Web.Endpoint)

  def base_path, do: "public"

  def generate(urls, opts \\ []) when is_list(urls) do
    conn = Phoenix.ConnTest.build_conn()
    dest = opts[:output_dir] || Config.get([__MODULE__, :output_dir]) || "#{static_dir()}#{base_path()}"

    maybe_clean_and_copy_assets(dest, opts)

    urls
    |> Enum.map(fn url -> generate_html(conn, url) end)
    |> debug()
    |> Enum.map(fn
      {:error, e} -> {:error, e}
      {url, content} -> write_file(url, content, dest)
    end)
    |> info()
  end
  def generate(url, opts) do
    with [ok: _] <- generate([url], opts) do
      :ok
    end
  end

  def static_dir() do
    src = ["priv","static"] |> Path.join() |> Path.relative_to_cwd()
    src <> "/"
  end

  def generate_html(conn, url) do
    with html when is_binary(html) <- html_response(get(conn, url), 200) do
      {url, html}
    else e ->
      {:error, e}
    end
  end

  def write_file(path, content, dest) do
    full_path = Path.join([dest, path, "index.html"])
    dirname   = Path.dirname(full_path)
    with :ok <- File.mkdir_p(dirname),
         :ok <- File.write(full_path, content) do
      {:ok, path}
    else
      _ -> {:error, path}
    end
  end

  defp maybe_clean_and_copy_assets(dest, opts) do
    static_dir = static_dir()
    if not String.starts_with?(dest, static_dir) do
      debug("Copy all static assets as well")
      if opts[:delete_dest_first], do: clean_files(dest)
      copy_assets(static_dir, dest)
    else
      debug("Skip copying static assets")
    end
  end

  defp clean_files(dest) do
    with {:ok, _} <- File.rm_rf(dest) do
      :ok
    else
      error -> error(error)
    end
  end

  def copy_assets(src, dest) do
    pars = ["-r", src, dest]
    with {_out, 0} <- System.cmd("rsync", pars) do
      :ok
    else
      error -> error(error)
    end
  end

end
