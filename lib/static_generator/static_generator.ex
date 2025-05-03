defmodule Bonfire.UI.Common.StaticGenerator do
  @moduledoc """
  Static-site generator which can take a list of URLs served by the current Phoenix server and output static HTML for them
  """
  # import Plug.Conn
  # import Phoenix.ConnTest
  use Untangle
  use Bonfire.Common.Config

  @endpoint Config.get(:endpoint_module, Bonfire.Web.Endpoint)

  use Oban.Worker,
    queue: :static_generator,
    max_attempts: 1

  @impl Oban.Worker
  def perform(_job) do
    batch()
    :ok
  end

  def batch do
    # TODO: paths to cache in config
    generate(["/", "/about", "/conduct", "/privacy"])
  end

  def base_path, do: "public"

  defp static_dir() do
    Path.join(["priv", "static", base_path()]) <> "/"
  end

  def maybe_generate(urls, opts \\ [])

  def maybe_generate(urls, opts) when is_list(urls) do
    # TODO: ttl
    dest = dest_dir(opts)
    opts = opts ++ [dest: dest]

    urls
    |> Enum.reject(fn url ->
      full_path = Path.join([dest, url, "index.#{opts[:ext] || "html"}"])
      file_exists_not_expired(full_path)
    end)
    |> debug("expired or doesn't exist")
    |> generate(opts)
  end

  def maybe_generate(url, opts) do
    maybe_generate([url], opts)
  end

  @decorate time()
  def generate(urls, opts \\ [])

  def generate(urls, opts) when is_list(urls) do
    conn = Phoenix.ConnTest.build_conn()

    dest = opts[:dest] || dest_dir(opts)

    maybe_clean_and_copy_assets(dest, opts)

    urls
    |> Enum.map(fn url ->
      with {:ok, html} <- generate_html(conn, url) do
        write_file(url, html, dest)
      end
    end)
    |> IO.inspect(label: "generated and written")
    |> Enum.frequencies_by(fn
      {:ok, _path} ->
        :ok

      other ->
        error(other, "Could not generate")
        :error
    end)
    |> debug("ret")
  end

  def generate(url, opts) do
    generate([url], opts)
  end

  defp generate_html(conn, url) do
    with html when is_binary(html) <-
           get(conn, url, %{"cache" => "skip"})
           |> Phoenix.ConnTest.html_response(200) do
      {:ok, html}
    else
      e ->
        {:error, e}
    end
  end

  def get(conn, url, params_or_body) do
    if function_exported?(Phoenix.ConnTest, :get, 3) do
      Phoenix.ConnTest.get(conn, url, params_or_body)
    else
      Phoenix.ConnTest.dispatch(
        conn,
        Bonfire.Common.Config.endpoint_module(),
        :get,
        url,
        params_or_body
      )
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

  defp dest_dir(opts) do
    Application.app_dir(
      Config.get(:umbrella_otp_app) || Config.get!(:otp_app),
      opts[:output_dir] || Config.get([__MODULE__, :output_dir]) ||
        static_dir()
    )
    |> debug()
  end

  def file_exists_not_expired(file) do
    case file_exists_age(file) |> debug("age") do
      false -> false
      # seconds
      age -> age < 60
    end
  end

  def file_exists_age(file) when is_binary(file) do
    with {:ok, %{ctime: ts}} <- File.stat(file, time: :posix) do
      System.os_time(:second) - ts
      # date
      # |> DateTime.from_unix!()
      # |> debug
      # |> DateTime.diff(..., DateTime.utc_now(), :second)
      # |> debug
    else
      _ ->
        false
    end
  end
end
