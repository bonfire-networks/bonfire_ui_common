defmodule Bonfire.UI.Common.RemoteIPTrustTest do
  @moduledoc """
  A client's address (used for rate limits and logs) comes from forwarding headers like `x-forwarded-for` only when the request arrives from a trusted proxy (loopback and private networks by default, plus any configured `TRUSTED_PROXIES`). A client connecting directly cannot choose its own address by sending the header.
  """
  use Bonfire.UI.Common.ConnCase, async: true
  @moduletag :ui

  @public_peer {203, 0, 113, 9}

  defp remote_ip_after(conn), do: get(conn, "/login").remote_ip

  test "a direct client keeps its address when it sends no forwarding header" do
    assert remote_ip_after(%{conn() | remote_ip: @public_peer}) == @public_peer
  end

  test "a direct client cannot choose its address with x-forwarded-for" do
    conn =
      %{conn() | remote_ip: @public_peer}
      |> put_req_header("x-forwarded-for", "198.51.100.7")

    assert remote_ip_after(conn) == @public_peer
  end

  test "a reverse proxy on the same host or a private network still passes the client's address on" do
    for proxy <- [{127, 0, 0, 1}, {10, 1, 2, 3}, {172, 18, 0, 2}, {192, 168, 1, 5}] do
      conn =
        %{conn() | remote_ip: proxy}
        |> put_req_header("x-forwarded-for", "198.51.100.7")

      assert remote_ip_after(conn) == {198, 51, 100, 7}
    end
  end

  test "a configured trusted proxy on a public address passes the client's address on" do
    Process.put([:bonfire_ui_common, :trusted_proxies], ["203.0.113.0/24"])

    conn =
      %{conn() | remote_ip: @public_peer}
      |> put_req_header("x-forwarded-for", "198.51.100.7")

    assert remote_ip_after(conn) == {198, 51, 100, 7}
  end
end
