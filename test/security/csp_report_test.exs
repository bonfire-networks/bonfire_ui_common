defmodule Bonfire.UI.Common.CSPReportTest do
  @moduledoc """
  Browsers POST the violations of the report-only script policy to `/csp-report`, in two formats (`application/csp-report` and `application/reports+json`). The endpoint needs no session or CSRF token, answers 204 at once, logs each new violation once at warning level, and drops the noise of browser extensions.
  """
  # not async: the warning is only logged when the global log level lets it through (CI may run higher), and the rate limit counters are shared
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  @path "/csp-report"

  defp unique, do: Needle.UID.generate()

  # the log level is raised for the run of `fun`
  defp capture_warnings(fun) do
    previous = Logger.level()
    Logger.configure(level: :warning)

    try do
      ExUnit.CaptureLog.capture_log([level: :warning], fun)
    after
      Logger.configure(level: previous)
    end
  end

  defp legacy(blocked, extra \\ %{}) do
    Jason.encode!(%{
      "csp-report" =>
        Map.merge(
          %{
            "document-uri" => "https://bonfire.local/",
            "effective-directive" => "script-src-elem",
            "blocked-uri" => blocked,
            "source-file" => "https://bonfire.local/feed",
            "line-number" => 12,
            "disposition" => "report"
          },
          extra
        )
    })
  end

  defp modern(blocked, extra \\ %{}) do
    Jason.encode!([
      %{
        "type" => "csp-violation",
        "url" => "https://bonfire.local/",
        "body" =>
          Map.merge(
            %{
              "documentURL" => "https://bonfire.local/",
              "effectiveDirective" => "script-src-elem",
              "blockedURL" => blocked,
              "sourceFile" => "https://bonfire.local/feed",
              "lineNumber" => 12,
              "disposition" => "report"
            },
            extra
          )
      }
    ])
  end

  defp report(body, content_type) do
    conn()
    |> put_req_header("content-type", content_type)
    |> post(@path, body)
  end

  test "an application/csp-report body is answered 204 and logged once with directive and blocked URL" do
    blocked = "https://legacy-#{unique()}.example"

    log =
      capture_warnings(fn ->
        assert %{status: 204} = report(legacy(blocked), "application/csp-report")
      end)

    assert log =~ "script-src-elem"
    assert log =~ blocked
  end

  test "an application/reports+json body is answered 204 and logged once with directive and blocked URL" do
    blocked = "https://modern-#{unique()}.example"

    log =
      capture_warnings(fn ->
        assert %{status: 204} = report(modern(blocked), "application/reports+json")
      end)

    assert log =~ "script-src-elem"
    assert log =~ blocked
  end

  test "an inline violation keeps its sample, and `inline` and `eval` are not treated as noise" do
    sample = "alert(#{unique()})"

    log =
      capture_warnings(fn ->
        report(modern("inline", %{"sample" => sample}), "application/reports+json")

        report(
          legacy("eval", %{"source-file" => "https://bonfire.local/#{unique()}"}),
          "application/csp-report"
        )
      end)

    assert log =~ sample
    assert log =~ "eval"
  end

  test "the same report twice is logged once" do
    body = legacy("https://twice-#{unique()}.example")

    log =
      capture_warnings(fn ->
        assert %{status: 204} = report(body, "application/csp-report")
        assert %{status: 204} = report(body, "application/csp-report")
      end)

    assert length(String.split(log, "CSP report-only violation")) == 2
  end

  test "reports of browser extensions and about: pages are answered 204 and not logged" do
    # control: a real violation in the same run is logged
    real = "https://control-#{unique()}.example"

    log =
      capture_warnings(fn ->
        for scheme <-
              ~w(chrome-extension moz-extension safari-extension safari-web-extension ms-browser-extension about) do
          assert %{status: 204} =
                   report(legacy("#{scheme}://noise-xyz/a.js"), "application/csp-report")

          assert %{status: 204} = report(legacy(scheme), "application/csp-report")

          assert %{status: 204} =
                   report(
                     modern("https://x.example", %{"sourceFile" => "#{scheme}://noise-xyz/a.js"}),
                     "application/reports+json"
                   )
        end

        assert %{status: 204} = report(legacy("about:blank"), "application/csp-report")
        report(legacy(real), "application/csp-report")
      end)

    assert log =~ real
    refute log =~ "noise-xyz"
    refute log =~ "about"
    refute log =~ "extension"
  end

  test "needs no session or CSRF token: a plain conn is enough and no session cookie is set" do
    conn = report(legacy("https://plain-#{unique()}.example"), "application/csp-report")

    assert conn.status == 204
    assert conn.resp_body == ""
    assert Plug.Conn.get_resp_header(conn, "set-cookie") == []
  end

  test "garbage bodies are answered 204 and not logged" do
    log =
      capture_warnings(fn ->
        assert %{status: 204} = report("not json", "application/csp-report")
        assert %{status: 204} = report("[1, 2, \"x\"]", "application/reports+json")
        assert %{status: 204} = report("{\"csp-report\": 5}", "application/csp-report")
      end)

    refute log =~ "CSP report-only violation"
  end

  test "a body over the cap is answered 413 and not processed" do
    blocked = "https://big-#{unique()}.example"
    body = legacy(blocked, %{"script-sample" => String.duplicate("a", 20_000)})
    assert byte_size(body) > 16_384

    log =
      capture_warnings(fn ->
        assert %{status: 413} = report(body, "application/csp-report")
      end)

    refute log =~ blocked
  end

  test "over the rate limit, reports are dropped without being logged" do
    # the limiter may be switched off for the test run (ENABLE_RATE_LIMIT=no)
    Process.put([:bonfire, :rate_limit, :disabled], false)
    Process.put([:bonfire, :rate_limit, :csp_report], limit: 2, scale_ms: 60_000)
    # the counters outlive a test
    Bonfire.UI.Common.RateLimit.set("csp_report:127.0.0.1", 60_000, 0)

    blocked = fn n -> "https://limited-#{n}-#{unique()}.example" end
    [one, two, three] = for n <- 1..3, do: blocked.(n)

    log =
      capture_warnings(fn ->
        for b <- [one, two, three] do
          assert %{status: 204} = report(legacy(b), "application/csp-report")
        end
      end)

    # control: the ones within the limit are logged
    assert log =~ one
    assert log =~ two
    refute log =~ three
  end
end
