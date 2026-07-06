defmodule Bonfire.UI.Common.GuestCookielessTest do
  @moduledoc """
  Guests must stay COOKIELESS (GDPR: nothing to consent to; caching: no `Set-Cookie` busting shared caches on public pages; and the overload shed plug's cookie-presence check stays acorrect login discriminator). This exercises the FULL pipeline, so it catches any session writer for guests, known ones gated so far: `save_accept_header` (cookie-carriers only) and the root layout's `csrf_meta_tag` (guest LVs are dead renders that never connect).
  """
  use Bonfire.UI.Common.ConnCase, async: false

  defp session_cookies(conn) do
    conn
    |> Plug.Conn.get_resp_header("set-cookie")
    |> Enum.filter(&String.contains?(&1, "_bonfire_key"))
  end

  defp get_following_redirect(path, hops \\ 3)
  defp get_following_redirect(_path, 0), do: flunk("too many redirects")

  defp get_following_redirect(path, hops) do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "text/html")
      |> get(path)

    assert session_cookies(conn) == [],
           "guest response for #{path} (status #{conn.status}) must not set a session cookie — " <>
             "session written: #{inspect(conn.private[:plug_session])}; " <>
             "session info flag: #{inspect(conn.private[:plug_session_info])}; " <>
             "set-cookie: #{inspect(Enum.map(Plug.Conn.get_resp_header(conn, "set-cookie"), &String.slice(&1, 0, 80)))}; " <>
             "csrf meta tag: #{String.contains?(to_string(conn.resp_body), "csrf-token")}; " <>
             "csrf form inputs: #{length(String.split(to_string(conn.resp_body), "_csrf_token")) - 1}"

    case {conn.status, Plug.Conn.get_resp_header(conn, "location")} do
      {status, [location | _]} when status in [301, 302] and binary_part(location, 0, 1) == "/" ->
        get_following_redirect(location, hops - 1)

      _ ->
        conn
    end
  end

  test "a fresh guest page load (home + wherever it redirects) sets NO session cookie" do
    # `?test=guest_cookieless` busts the StaticGeneratedPlug snapshot so pages LIVE-render
    # (a static-served page never hits the session-writing plugs — a false green)
    for path <- [
          "/",
          "/?test=guest_cookieless",
          "/feed/local?test=guest_cookieless",
          "/feed?test=guest_cookieless",
          "/about?test=guest_cookieless",
          "/groups",
          "/conduct?test=guest_cookieless",
          "/"
        ] do
      conn = get_following_redirect(path)
      assert conn.status == 200, "expected 200 for #{path}, got #{conn.status}"
    end
  end

  test "auth form pages DO set the strictly-necessary session cookie (CSRF for the form POST)" do
    # the exempt case (ePrivacy Art. 5(3) via WP194 criterion B): the form the guest explicitly requested cannot POST safely without the session-stored CSRF token
    for path <- ["/login", "/signup"] do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "text/html")
        |> get(path)

      assert conn.status == 200
      assert session_cookies(conn) != [], "expected #{path} to set the session cookie"
      assert Map.has_key?(conn.private[:plug_session] || %{}, "_csrf_token")
    end
  end
end
