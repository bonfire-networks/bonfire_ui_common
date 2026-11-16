defmodule Bonfire.UI.Common.Plugs.CSPReport do
  @moduledoc """
  Receives the Content-Security-Policy violation reports that browsers POST to `path/0`, so the report-only script policy shows what enforcing it would break.

  Both report formats are accepted: the older `report-uri` one (`application/csp-report`, a single `{"csp-report": {...}}` with kebab-case keys) and the Reporting API one (`application/reports+json`, an array of `{"type": "csp-violation", "body": {...}}`). Both are normalised to one shape (directive, blocked URL, source file, line, disposition, sample, document URL).

  Everything in a report is attacker-controlled: any client can post anything. Strings are cut short and only ever logged (escaped), never rendered or stored.

  The reports from browser extensions (`chrome-extension:`, `moz-extension:`, ...) and `about:` pages are dropped, as they say nothing about our pages. `inline` and `eval` are kept: those are the reports that matter. Each new combination of directive, blocked URL and source file is logged once (at warning level) until the dedupe entry expires, so a broken page seen by many visitors does not flood the logs.

  The answer is always `204`, except `413` for a body over the cap, which is not processed. A request over the per-IP rate limit is answered `204` and dropped without being read.

  This plug is in the endpoint, ahead of `Plug.Parsers` (which would otherwise read and decode a body of up to its own much larger limit before the router runs), and so also ahead of the session, CSRF and auth: a report carries no cookie or token. It reads and decodes the body itself, so the content type does not matter.

  Config:
  - `config :bonfire_ui_common, :csp_report_max_bytes, 16_384` the body cap
  - `config :bonfire_ui_common, :csp_report_dedupe_ms, :timer.hours(1)` how long a logged combination is not logged again
  - `config :bonfire, :rate_limit, csp_report: [scale_ms: 60_000, limit: 60]` the per-IP rate limit (as for the other limited routes)

  Cost: a request to other paths pays one path comparison. A report pays one rate-limit counter hit, a read of at most the cap, one JSON decode, and one cache lookup per report in it (plus one cache write and one log line when new).
  """
  @behaviour Plug

  import Plug.Conn
  require Logger
  require Bonfire.Common.Config

  @path "/csp-report"
  @max_bytes 16_384
  @dedupe_ms :timer.hours(1)
  @max_string 200
  @max_reports 10

  # `scheme:` of what extensions and browser-internal pages report as blocked or source
  @noise_schemes ~w(chrome-extension moz-extension safari-extension safari-web-extension ms-browser-extension about)

  @doc "The route reports are posted to."
  def path, do: @path

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: "POST", request_path: @path} = conn, _opts) do
    conn
    |> handle()
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp handle(conn) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case Bonfire.UI.Common.RateLimit.check(:csp_report, ip, 60_000, 60) do
      :ok -> read(conn)
      {:error, _retry_after} -> send_resp(conn, 204, "")
    end
  end

  defp read(conn) do
    max = Bonfire.Common.Config.get([:bonfire_ui_common, :csp_report_max_bytes], @max_bytes)

    case read_body(conn, length: max, read_length: max) do
      {:ok, body, conn} ->
        body |> decode() |> normalise() |> Enum.each(&log_once/1)
        send_resp(conn, 204, "")

      {:more, _partial, conn} ->
        send_resp(conn, 413, "")

      _ ->
        send_resp(conn, 204, "")
    end
  end

  defp decode(body) do
    case Phoenix.json_library().decode(body) do
      {:ok, decoded} -> decoded
      _ -> nil
    end
  end

  @doc "Turns a decoded report body (either format) into a list of normalised reports, noise dropped."
  def normalise(%{"csp-report" => %{} = report}), do: normalise_legacy(report)

  def normalise(list) when is_list(list) do
    list
    |> Enum.take(@max_reports)
    |> Enum.flat_map(fn
      %{"type" => "csp-violation", "body" => %{} = body} -> normalise_modern(body)
      _ -> []
    end)
  end

  def normalise(_), do: []

  defp normalise_legacy(r) do
    keep(%{
      directive: str(r["effective-directive"] || r["violated-directive"]),
      blocked_url: str(r["blocked-uri"]),
      source_file: str(r["source-file"]),
      line: int(r["line-number"]),
      disposition: str(r["disposition"]),
      sample: str(r["script-sample"]),
      document_url: str(r["document-uri"])
    })
  end

  defp normalise_modern(r) do
    keep(%{
      directive: str(r["effectiveDirective"]),
      blocked_url: str(r["blockedURL"]),
      source_file: str(r["sourceFile"]),
      line: int(r["lineNumber"]),
      disposition: str(r["disposition"]),
      sample: str(r["sample"]),
      document_url: str(r["documentURL"])
    })
  end

  defp keep(report), do: if(noise?(report), do: [], else: [report])

  defp noise?(%{blocked_url: blocked, source_file: source}),
    do: noise_url?(blocked) or noise_url?(source)

  defp noise_url?(url) when is_binary(url),
    do: Enum.any?(@noise_schemes, &(url == &1 or String.starts_with?(url, &1 <> ":")))

  defp noise_url?(_), do: false

  defp str(value) when is_binary(value), do: String.slice(value, 0, @max_string)
  defp str(_), do: nil

  defp int(value) when is_integer(value), do: value
  defp int(_), do: nil

  defp log_once(report) do
    key =
      {report.directive, report.blocked_url, report.source_file}
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16()
      |> then(&"csp_report:#{&1}")

    case Bonfire.Common.Cache.get(key) do
      {:ok, nil} ->
        Bonfire.Common.Cache.put(key, true,
          expire:
            Bonfire.Common.Config.get([:bonfire_ui_common, :csp_report_dedupe_ms], @dedupe_ms)
        )

        Logger.warning(
          "CSP report-only violation: #{inspect(report, limit: 20, printable_limit: @max_string)}"
        )

      _ ->
        :ok
    end
  end
end
