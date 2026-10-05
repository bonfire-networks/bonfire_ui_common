defmodule Bonfire.UI.Common.GoAfterCookieTest do
  @moduledoc """
  Where to go after signing in is kept in a cookie of its own, `_bonfire_go`, which the browser deletes after a few minutes, rather than in the session, where an abandoned flow's target (an OAuth authorization, say) lasted as long as the session and hijacked a later sign-in.
  """
  use ExUnit.Case, async: true
  @moduletag :ui

  alias Bonfire.UI.Common

  @cookie "_bonfire_go"

  defp conn(path \\ "/login") do
    Plug.Test.conn(:get, path)
    |> Map.put(:secret_key_base, Bonfire.Common.Config.endpoint_module().config(:secret_key_base))
    |> Plug.Test.init_test_session(%{})
  end

  # the next request from the same browser, which sends back the cookies the last response set
  defp next_request(response, path \\ "/login") do
    conn(path) |> Plug.Test.recycle_cookies(response)
  end

  defp sign_in(conn, params \\ %{}),
    do: Common.redirect_to_previous_go(conn, params, "/home", "/login")

  test "set_go_after/2 keeps the target in an encrypted cookie that expires, not in the session" do
    response =
      conn("/oauth/authorize?client_id=x") |> Common.set_go_after("/oauth/authorize?client_id=x")

    assert %{value: value, max_age: max_age} = response.resp_cookies[@cookie]
    assert max_age == div(to_timeout(minute: 15), 1000)
    refute value =~ "authorize", "encrypted, so it can't be read or planted"
    assert Plug.Conn.get_session(response, :go) == nil
  end

  test "signing in goes to the target, and the cookie is deleted" do
    response = conn() |> Common.set_go_after("/settings")

    signed_in = response |> next_request() |> sign_in()

    assert Phoenix.ConnTest.redirected_to(signed_in) == "/settings"
    assert %{max_age: 0} = signed_in.resp_cookies[@cookie]
  end

  test "once the browser has expired the cookie, an abandoned flow isn't resumed" do
    # what an expired cookie looks like to the server: absent
    assert Phoenix.ConnTest.redirected_to(conn() |> sign_in()) == "/home"
  end

  test "a target stored in the session before this change isn't acted on, and is cleared" do
    signed_in =
      conn()
      |> Plug.Conn.put_session(:go, "/oauth/authorize?client_id=stale")
      |> sign_in()

    assert Phoenix.ConnTest.redirected_to(signed_in) == "/home"
    assert Plug.Conn.get_session(signed_in, :go) == nil
  end

  test "a go param still applies when there's no cookie" do
    assert Phoenix.ConnTest.redirected_to(conn() |> sign_in(%{"go" => "/feed"})) == "/feed"
  end

  test "a planted, unencrypted cookie is ignored" do
    signed_in =
      conn()
      |> Plug.Test.put_req_cookie(@cookie, "/oauth/authorize?client_id=planted")
      |> sign_in()

    assert Phoenix.ConnTest.redirected_to(signed_in) == "/home"
  end
end
