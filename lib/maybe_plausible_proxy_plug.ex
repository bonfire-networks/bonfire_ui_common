defmodule Bonfire.UI.Common.MaybePlausibleProxyPlug do
  @moduledoc """
  Proxies the Plausible analytics script and `/api/event` endpoint when enabled via the
  `:bonfire_ui_common, :plausible_proxy` config (see `Bonfire.UI.Common.RuntimeConfig`).

  Re-implemented instead of delegating to `PlausibleProxy.Plug`: that library forwards all
  of Plausible's upstream response headers (including `Content-Length`), which combined with
  the one Plug/Cowboy sets produces a duplicate `Content-Length`. A strict reverse proxy
  (e.g. Traefik) rejects that as invalid and returns `502`. Here we forward only safe headers.
  """
  @behaviour Plug

  require Logger
  import Plug.Conn

  @plausible_base "https://plausible.io"
  @default_local_path "/js/plausible_script.js"
  @default_script_extension "script.js"
  @default_remote_ip_headers ["fly-client-ip", "x-real-ip"]
  @forwardable ~w(content-type cache-control x-content-type-options)

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:bonfire_ui_common, :plausible_proxy, [])
    if config[:enabled], do: maybe_proxy(conn, config), else: conn
  end

  defp maybe_proxy(%{request_path: path} = conn, config) do
    cond do
      path == (config[:local_path] || @default_local_path) -> serve_script(conn, config)
      path == "/api/event" -> proxy_event(conn, config)
      true -> conn
    end
  end

  defp serve_script(conn, config) do
    ext = config[:script_extension] || @default_script_extension
    url = "#{@plausible_base}/js/#{ext}"

    case HTTPoison.get(url, build_headers(conn, config)) do
      {:ok, resp} ->
        conn
        |> forward_safe_headers(resp.headers)
        |> send_resp(resp.status_code, resp.body)
        |> halt()

      {:error, error} ->
        # fall through (will 404) rather than hang/crash
        Logger.warning("PlausibleProxy: failed to fetch script from #{url}: #{inspect(error)}")
        conn
    end
  end

  defp proxy_event(conn, config) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, payload} <- Jason.decode(body),
         remote_ip = determine_ip_address(conn, config),
         headers = build_headers(conn, [{"Content-Type", "application/json"}], remote_ip),
         event = Jason.encode!(%{"name" => payload["n"], "url" => payload["u"], "domain" => payload["d"]}),
         {:ok, resp} <- HTTPoison.post("#{@plausible_base}/api/event", event, headers) do
      conn
      |> forward_safe_headers(resp.headers)
      |> send_resp(resp.status_code, resp.body)
      |> halt()
    else
      error ->
        Logger.warning("PlausibleProxy: failed to proxy event: #{inspect(error)}")
        conn |> send_resp(502, "Reverse Proxy failed") |> halt()
    end
  end

  # Never forward Content-Length / Content-Encoding / Transfer-Encoding: Plug/Cowboy set their
  # own and duplicates make a strict reverse proxy (Traefik) reject the response with a 502.
  defp forward_safe_headers(conn, upstream_headers) do
    Enum.reduce(upstream_headers, conn, fn {k, v}, acc ->
      k = String.downcase(k)
      if k in @forwardable, do: put_resp_header(acc, k, v), else: acc
    end)
  end

  defp build_headers(conn, config), do: build_headers(conn, [], determine_ip_address(conn, config))

  defp build_headers(conn, extra, ip_address) do
    [
      {"X-Forwarded-For", ip_address},
      {"User-Agent", conn |> get_req_header("user-agent") |> List.first()}
      | extra
    ]
  end

  defp determine_ip_address(conn, config) do
    (config[:remote_ip_headers] || @default_remote_ip_headers)
    |> Enum.find_value(fn h -> conn |> get_req_header(h) |> List.first() end) ||
      List.to_string(:inet.ntoa(conn.remote_ip))
  end
end
