defmodule Bonfire.UI.Common.OverloadShedPlug do
  @moduledoc """
  Sheds traffic when `Bonfire.Common.Overload` reports overload, the class×level shed matrix in one plug.

  Plugged in the endpoint right AFTER `mark_process_context` (whose `caller_class` Logger-metadata classification it reuses via a local read) and therefore BEFORE the router, so federation requests are shed before HTTP-signature crypto, which is the point: saving CPU.

  Matrix (default traffic ranking hardcoded; the Calm-editable ordering comes with the priority-list knob): at `:hard`, `:ap` requests get `429` + adaptive `Retry-After` (well-behaved fediverse servers re-deliver later, so load gets shaped and activities delayed, not lost, unlike 500s which trigger aggressive retries or permanent drops). Browser/`:api` shedding (fail-whale redirect) is the next cell to fill in.

  Every shed is recorded via `Overload.shed/2` (telemetry + log), false positives must be visible. Zero cost when calm: one persistent_term read.
  """
  @behaviour Plug
  import Plug.Conn

  alias Bonfire.Common.Overload

  def init(opts), do: opts

  def call(conn, _opts) do
    # cheap pull read; :ok covers :monitor mode and stand-down too
    case Overload.level() do
      :ok -> conn
      level -> maybe_shed(conn, Logger.metadata()[:caller_class], level)
    end
  end

  # federation sheds only at :hard, deliveries get DELAYED (remote servers honor Retry-After
  # and requeue), so it ranks above the anonymous-browser tier in the default ordering
  defp maybe_shed(conn, :ap, :hard) do
    retry_after = Overload.retry_after()
    Overload.shed(:federation, __MODULE__)

    conn
    |> put_resp_header("retry-after", to_string(retry_after))
    # JSON: AP/API clients expect it and some implementations parse the error body
    |> put_resp_content_type("application/json")
    |> send_resp(
      429,
      Jason.encode!(%{
        error: "Too Many Requests: instance is under heavy load, please retry later",
        retry_after: retry_after
      })
    )
    |> halt()
  end

  # guest/crawler page loads (GET, no session cookie, with a header check, no DB) are the cheapest
  # tier: shed from :soft up with the fail-whale redirect. Logged-in humans are the last
  # standing and keep flowing. The redirect target is the ALREADY-SW-PRECACHED offline.html in
  # "crowded" hash-mode with a jittered countdown back to the original destination, the
  # server's whole cost per shed is this ~200-byte redirect.
  defp maybe_shed(%Plug.Conn{method: "GET"} = conn, :web, _level) do
    if session_cookie?(conn) do
      conn
    else
      retry_after = Overload.retry_after()
      Overload.shed(:guest_web, __MODULE__)
      back = URI.encode_www_form(conn.request_path <> query_suffix(conn))

      conn
      |> put_resp_header("retry-after", to_string(retry_after))
      |> put_resp_header("location", "/pwa/offline.html#overloaded=#{retry_after}&back=#{back}")
      |> send_resp(302, "")
      |> halt()
    end
  end

  # api tiers (authed = mobile users vs anon) + the Calm-editable ranking: future matrix cells
  defp maybe_shed(conn, _class, _level), do: conn

  defp query_suffix(%Plug.Conn{query_string: ""}), do: ""
  defp query_suffix(%Plug.Conn{query_string: q}), do: "?" <> q

  # guests are kept cookieless (see EndpointTemplate.session_cookie?/1 + the csrf-meta-tag
  # gating in the root layout), so cookie presence ≈ logged in / mid-auth — free to check
  defp session_cookie?(conn), do: Bonfire.UI.Common.EndpointTemplate.session_cookie?(conn)
end
