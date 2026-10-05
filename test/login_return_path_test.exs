defmodule Bonfire.UI.Common.LoginReturnPathTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Common

  # the go target is an encrypted cookie, which needs the endpoint's key
  defp new_conn do
    Plug.Test.conn(:get, "/login")
    |> Map.put(:secret_key_base, Bonfire.Common.Config.endpoint_module().config(:secret_key_base))
    |> Plug.Test.init_test_session(%{})
  end

  for source <- [:session, :form, :nested_form, :default] do
    @source source
    test "preserves encoded path and query values from #{@source}" do
      values = %{"state" => "state & + / café", "next" => "/inbox?filter=a&sort=b"}
      destination = "/search/saved%2Fquery?" <> Plug.Conn.Query.encode(values)
      conn = new_conn()

      {conn, params, default} =
        case @source do
          # saved by one request, read by the next, which gets the cookie back as a browser would send it
          :session ->
            {new_conn() |> Plug.Test.recycle_cookies(Common.set_go_after(conn, destination)), %{},
             "/"}

          :form ->
            {conn, %{"go" => destination}, "/"}

          :nested_form ->
            {conn, %{data: %{go: destination}}, "/"}

          :default ->
            {conn, %{}, destination}
        end

      response = Common.redirect_to_previous_go(conn, params, default, "/login")

      assert Plug.Conn.get_resp_header(response, "location") == [destination]

      assert Phoenix.ConnTest.redirected_to(response)
             |> URI.parse()
             |> Map.fetch!(:query)
             |> Plug.Conn.Query.decode() == values

      assert Plug.Conn.get_session(response, :go) == nil
    end
  end
end
