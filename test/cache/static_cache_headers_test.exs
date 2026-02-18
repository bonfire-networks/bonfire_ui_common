defmodule Bonfire.UI.Common.StaticCacheHeadersTest do
  @moduledoc """
  Verifies that Plug.Static sets the correct Cache-Control headers on static assets.

  - Fingerprinted requests (`?vsn=...`) → `public, max-age=31536000, immutable`
  - Plain requests (ETag path) → `public, max-age=86400`

  The max-age values reflect the defaults set in `EndpointTemplate` and can be overridden at compile time via `CACHE_STATIC_VSN_MAX_AGE` /
  `CACHE_STATIC_ETAG_MAX_AGE` env vars.
  """

  use Bonfire.UI.Common.ConnCase, async: true

  # Default max-age values (seconds) matching EndpointTemplate defaults.
  @vsn_max_age div(to_timeout(week: 52), 1_000)
  @etag_max_age div(to_timeout(day: 1), 1_000)

  describe "versioned JS asset (?vsn=)" do
    test "returns public, immutable Cache-Control with 1-year max-age" do
      conn = build_conn()
      conn = get(conn, "/assets/bonfire_basic.js?vsn=abcdef123")

      assert conn.status == 200

      assert [cache_control] = get_resp_header(conn, "cache-control")
      assert cache_control =~ "public"
      assert cache_control =~ "immutable"
      assert cache_control =~ "max-age=#{@vsn_max_age}"
    end
  end

  describe "versioned CSS asset (?vsn=)" do
    test "returns public, immutable Cache-Control with 1-year max-age" do
      conn = build_conn()
      conn = get(conn, "/assets/bonfire_basic.css?vsn=abcdef123")

      assert conn.status == 200

      assert [cache_control] = get_resp_header(conn, "cache-control")
      assert cache_control =~ "public"
      assert cache_control =~ "immutable"
      assert cache_control =~ "max-age=#{@vsn_max_age}"
    end
  end

  describe "favicon (non-versioned, ETag path)" do
    test "returns public Cache-Control with 1-day max-age" do
      conn = build_conn()
      conn = get(conn, "/favicon.ico")

      assert conn.status == 200

      assert [cache_control] = get_resp_header(conn, "cache-control")
      assert cache_control =~ "public"
      assert cache_control =~ "max-age=#{@etag_max_age}"
      refute cache_control =~ "immutable"
    end

    test "returns an ETag header" do
      conn = build_conn()

      conn = get(conn, "/favicon.ico")

      assert conn.status == 200
      assert get_resp_header(conn, "etag") != []
    end
  end
end
