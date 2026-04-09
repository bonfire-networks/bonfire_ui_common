defmodule Bonfire.UI.Common.StaticGenerator do
  @moduledoc """
  Static-site generator which can take a list of URLs served by the current Phoenix server and output static HTML for them
  """
  # import Plug.Conn
  # import Phoenix.ConnTest
  use Untangle
  use Bonfire.Common.Config

  alias Bonfire.Common.Cache

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
    dest = dest_path(opts)
    opts = opts ++ [dest: dest]

    urls
    |> Enum.reject(fn url ->
      full_path = Path.join([dest, url, "index.#{opts[:ext] || "html"}"])
      file_exists_not_expired(full_path)
    end)
    |> info("expired or doesn't exist")
    |> generate(opts)
  end

  def maybe_generate(url, opts) do
    maybe_generate([url], opts)
  end

  @decorate time()
  def generate(urls, opts \\ [])

  def generate(urls, opts) when is_list(urls) do
    conn = Phoenix.ConnTest.build_conn()

    dest = opts[:dest] || dest_path(opts)

    maybe_clean_and_copy_assets(dest, opts)

    urls
    |> Enum.map(fn url ->
      with {:ok, html} <- generate_html(conn, url) do
        # write_file(url, html, dest)
        cache_response(url, "text/html", html, opts ++ [root_path: dest])
      end
    end)
    |> debug("generated and written")
    |> Enum.frequencies_by(fn
      {:ok, _path} ->
        :ok

      other ->
        error(other, "Could not generate")
        :error
    end)
    |> info("ret")
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

  @session_opts Plug.Session.init(store: :cookie, key: "_bench", signing_salt: "bench_salt")

  def build_bench_conn(url, params \\ %{}) do
    query_string = URI.encode_query(params)
    path = if query_string != "", do: url <> "?" <> query_string, else: url

    secret = Application.get_env(:bonfire, @endpoint)[:secret_key_base] ||
             String.duplicate("benchsalt", 9)

    Plug.Test.conn(:get, path)
    |> Map.put(:secret_key_base, secret)
    |> Plug.Session.call(@session_opts)
    |> Plug.Conn.fetch_session()
  end

  def call_plug(conn) do
    Bonfire.UI.Common.MaybeStaticGeneratorPlug.call(conn, [])
  end

  @doc "Call the Phoenix endpoint directly as a plug, bypassing ConnTest overhead."
  def call_endpoint(conn) do
    @endpoint.call(conn, @endpoint.init([]))
  end

  def get_cached(url) do
    Bonfire.UI.Common.MaybeStaticGeneratorPlug.memory_cache_get(url)
  end

  def get_cached!(url) do
    result = get_cached(url)
    if is_nil(result), do: raise("get_cached!: nothing in memory cache for #{url}")
    result
  end


  defp maybe_clean_and_copy_assets(dest, opts) do
    if opts[:first_delete_output_dir], do: clean_files(dest)
    if opts[:copy_static_assets], do: copy_assets(static_dir(), dest)
  end

  defp clean_files(dest) do
    # TODO: use cache backend function
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

  @doc """
  Base directory where static files are written.

  Reads `output_dir` from opts, then config, then falls back to
  `priv/static/public/` under the OTP app's priv dir. If the resolved value
  is an absolute path it is used as-is; relative paths are resolved via
  `Application.app_dir`.

  In tests, set a process-local temp dir:

      Process.put([:bonfire_ui_common, Bonfire.UI.Common.StaticGenerator, :output_dir], "/tmp/my_dir")
  """
  def dest_path(opts \\ []) do
    dir = opts[:output_dir] || Config.get([__MODULE__, :output_dir]) || static_dir()

    if Path.type(dir) == :absolute do
      dir
    else
      Application.app_dir(Config.get(:umbrella_otp_app) || Config.get!(:otp_app), dir)
    end
    |> info("path")
  end


  @doc """
  Write a response body to the static cache at the given URL path.

  Writes via `Cache.Backend.put/4` with `root_path: dest_path(opts)` 
  """
  def cache_response(url, content_type, body, opts \\ []) do
        disk_backend = opts[:disk_cache_backend] || Bonfire.Common.Cache.SimpleDiskCache 

     
        root_path = opts[:root_path] || dest_path(opts)

        # store content_type file
      Bonfire.Common.Cache.Backend.put(disk_backend, "content_type:"<>url, content_type,
        root_path: root_path,
        async: opts[:async]
      )
  

    disk_backend = opts[:disk_cache_backend] || Bonfire.Common.Cache.SimpleDiskCache 

    Bonfire.Common.Cache.Backend.put(disk_backend, url, body,
        root_path: root_path,
        async: opts[:async]
      )
  end

  def get_content_type(url, opts \\ []) do
    disk_backend = opts[:disk_cache_backend] || Bonfire.Common.Cache.SimpleDiskCache 
        root_path = dest_path(opts)

    # get content_type from file cache
      case Bonfire.Common.Cache.Backend.get(disk_backend, "content_type:"<>url,
        root_path: root_path
      ) do
        {:ok, nil} -> nil
 {:ok, content_type} -> 
      # cache content_type 
      if content_type, do: Cache.put("static_gen_content_type:"<>url, content_type,
        cache_backend: Cache.default_cache_backend(),
        expire: to_timeout(day: 30),
        async: true
      )

      content_type

      other -> 
        error(other)
        nil
      end

  end

  def file_exists_not_expired(file) do
    case file_exists_age(file) |> info("age") do
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
