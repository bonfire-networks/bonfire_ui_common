defmodule Bonfire.UI.Common.SaveAcceptHeaderTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  # the endpoint compiles EndpointTemplate's plugs, including save_accept_header/2
  @endpoint Bonfire.Web.Endpoint

  defp with_session(conn) do
    opts = Plug.Session.init(Bonfire.UI.Common.EndpointTemplate.session_options())
    Plug.Session.call(conn, opts)
  end

  test "AP requests skip the session entirely (no cookie crypto, no Set-Cookie)" do
    conn =
      conn(:post, "/pub/shared_inbox")
      |> put_req_header("accept", "application/activity+json")

    # returned untouched: no session fetch (which would raise here — no session configured on
    # this conn — and in prod would decrypt + re-sign the cookie on every federation request)
    assert @endpoint.save_accept_header(conn, []) == conn

    conn =
      conn(:get, "/.well-known/webfinger") |> put_req_header("accept", "application/jrd+json")

    assert @endpoint.save_accept_header(conn, []) == conn

    conn = conn(:get, "/api/v1/instance") |> put_req_header("accept", "application/json")
    assert @endpoint.save_accept_header(conn, []) == conn
  end

  test "web requests store the accept header, but only dirty the session when it changed" do
    conn =
      conn(:get, "/feed")
      |> put_req_header("accept", "text/html")
      |> with_session()
      |> @endpoint.save_accept_header([])

    assert get_session(conn, :accept_header) == "text/html"
    # first write legitimately dirties the session
    assert conn.private.plug_session_info == :write

    # simulate the NEXT request with the same header: session already carries the value
    conn2 =
      conn(:get, "/feed")
      |> put_req_header("accept", "text/html")
      |> with_session()
      |> fetch_session()
      |> put_session(:accept_header, "text/html")

    # reset the dirty marker left by our test setup put_session
    conn2 = put_in(conn2.private[:plug_session_info], :ignore)

    conn2 = @endpoint.save_accept_header(conn2, [])

    # unchanged value → session NOT dirtied → no re-signed Set-Cookie on the response
    assert conn2.private.plug_session_info == :ignore
  end
end
