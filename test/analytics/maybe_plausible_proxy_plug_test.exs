defmodule Bonfire.UI.Common.MaybePlausibleProxyPlugTest do
  @moduledoc """
  Tests the Plausible analytics reverse-proxy plug (`Bonfire.UI.Common.MaybePlausibleProxyPlug`).

  The plug fetches through the Tesla-based `Bonfire.Common.HTTP`, so the default suite mocks the upstream with `Tesla.Mock` (config/test.exs sets `config :tesla, adapter: Tesla.Mock`); the `:live_federation`-tagged test hits the REAL Plausible endpoint (run with `--only live_federation`).

  Most important behaviour under test: only SAFE response headers are forwarded, and NEVER `Content-Length` (nor `Content-Encoding`/`Transfer-Encoding`), because Plug/Cowboy sets its own, and a duplicate `Content-Length` makes a strict reverse proxy (e.g. Traefik) reject with a 502.
  """
  use ExUnit.Case, async: false
  @moduletag :ui

  import Plug.Test
  import Plug.Conn
  import Tesla.Mock

  alias Bonfire.UI.Common.MaybePlausibleProxyPlug

  @local_script_path "/js/plausible_script.js"

  defp put_config(cfg) do
    original = Application.get_env(:bonfire_ui_common, :plausible_proxy)

    on_exit(fn ->
      if is_nil(original),
        do: Application.delete_env(:bonfire_ui_common, :plausible_proxy),
        else: Application.put_env(:bonfire_ui_common, :plausible_proxy, original)
    end)

    Application.put_env(:bonfire_ui_common, :plausible_proxy, cfg)
  end

  defp has_header?(headers, name, value),
    do: Enum.any?(headers, fn {k, v} -> String.downcase(k) == name and v == value end)

  describe "disabled / non-matching path (no upstream call)" do
    test "disabled → conn passes through untouched" do
      put_config(enabled: false)
      refute MaybePlausibleProxyPlug.call(conn(:get, @local_script_path), []).halted
    end

    test "enabled but path doesn't match → passes through" do
      put_config(enabled: true)
      refute MaybePlausibleProxyPlug.call(conn(:get, "/some/other/path"), []).halted
    end
  end

  describe "script proxy (mocked upstream)" do
    setup do
      put_config(enabled: true)
      :ok
    end

    test "forwards ONLY safe headers — drops upstream Content-Length/Encoding, keeps Content-Type/Cache-Control" do
      mock(fn %{method: :get} ->
        %Tesla.Env{
          status: 200,
          headers: [
            {"content-type", "application/javascript"},
            {"cache-control", "public, max-age=3600"},
            # MUST NOT be forwarded — Plug/Cowboy sets its own, a duplicate makes Traefik 502
            {"content-length", "24"},
            {"content-encoding", "gzip"},
            {"transfer-encoding", "chunked"}
          ],
          body: "console.log('plausible')"
        }
      end)

      result = MaybePlausibleProxyPlug.call(conn(:get, @local_script_path), [])

      assert result.halted
      assert result.status == 200
      assert result.resp_body == "console.log('plausible')"
      assert get_resp_header(result, "content-type") == ["application/javascript"]
      assert get_resp_header(result, "cache-control") == ["public, max-age=3600"]
      # the anti-502 fix — these are never forwarded from upstream:
      assert get_resp_header(result, "content-length") == []
      assert get_resp_header(result, "content-encoding") == []
      assert get_resp_header(result, "transfer-encoding") == []
    end

    test "upstream failure falls through (not halted, so the router 404s rather than hanging)" do
      mock(fn _ -> {:error, :econnrefused} end)
      refute MaybePlausibleProxyPlug.call(conn(:get, @local_script_path), []).halted
    end
  end

  describe "self-hosted Plausible (custom :base_domain / :script_path)" do
    test "fetches the script from the configured self-hosted instance, not plausible.io" do
      put_config(
        enabled: true,
        base_domain: "https://analytics.example.com",
        script_path: "/js/pl.js"
      )

      mock(fn %{method: :get, url: url} ->
        assert url == "https://analytics.example.com/js/pl.js"

        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/javascript"}],
          body: "self-hosted"
        }
      end)

      result = MaybePlausibleProxyPlug.call(conn(:get, @local_script_path), [])
      assert result.halted
      assert result.status == 200
      assert result.resp_body == "self-hosted"
    end

    test "posts events to the self-hosted /api/event" do
      put_config(enabled: true, base_domain: "https://analytics.example.com")

      mock(fn %{method: :post, url: url} ->
        assert url == "https://analytics.example.com/api/event"
        %Tesla.Env{status: 202, headers: [], body: "ok"}
      end)

      result =
        conn(:post, "/api/event", Jason.encode!(%{name: "pageview"}))
        |> put_req_header("content-type", "application/json")
        |> MaybePlausibleProxyPlug.call([])

      assert result.halted
      assert result.status == 202
    end
  end

  describe "/api/event proxy (mocked upstream)" do
    setup do
      put_config(enabled: true)
      :ok
    end

    test "forwards the payload verbatim + X-Forwarded-For from the remote-ip header" do
      body =
        Jason.encode!(%{name: "pageview", domain: "example.com", url: "https://example.com/"})

      mock(fn %{method: :post, url: url, body: req_body, headers: headers} ->
        assert String.ends_with?(url, "/api/event")

        # body forwarded verbatim (newer scripts send extra required fields that Plausible 400s on if stripped)
        assert req_body == body
        assert has_header?(headers, "x-forwarded-for", "203.0.113.7")
        %Tesla.Env{status: 202, headers: [{"content-type", "text/plain"}], body: "ok"}
      end)

      result =
        conn(:post, "/api/event", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-real-ip", "203.0.113.7")
        |> MaybePlausibleProxyPlug.call([])

      assert result.halted
      assert result.status == 202
    end

    test "upstream failure returns 502" do
      mock(fn %{method: :post} -> {:error, :timeout} end)

      result =
        conn(:post, "/api/event", Jason.encode!(%{name: "pageview"}))
        |> put_req_header("content-type", "application/json")
        |> MaybePlausibleProxyPlug.call([])

      assert result.halted
      assert result.status == 502
    end
  end

  describe "live integration (real Plausible)" do
    @describetag :live_federation

    setup do
      # in test env the global Tesla adapter is `Tesla.Mock`; swap in a real adapter so this test
      # actually reaches plausible.io (restored afterwards so it can't leak into other tests)
      original = Application.get_env(:tesla, :adapter)
      Application.put_env(:tesla, :adapter, {Tesla.Adapter.Hackney, []})
      on_exit(fn -> Application.put_env(:tesla, :adapter, original) end)
      put_config(enabled: true)
    end

    test "proxies the real Plausible script and never forwards Content-Length" do
      result = MaybePlausibleProxyPlug.call(conn(:get, @local_script_path), [])

      assert result.halted
      assert result.status == 200
      # the real Plausible script defines `window.plausible` — proves we proxied the actual JS
      assert result.resp_body =~ "window.plausible"
      assert get_resp_header(result, "content-length") == []
    end
  end
end
