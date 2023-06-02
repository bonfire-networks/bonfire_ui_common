defmodule Bonfire.UI.Common.PlugAttack do
  use PlugAttack

  rule "throttle form submissions (using controllers, not LiveView)", conn do
    #  limits the number of form submission that one IP address can make to 5 per minute
    if conn.method == "POST" do
      throttle(conn.remote_ip,
        period: 60_000,
        limit: 5,
        storage: {PlugAttack.Storage.Ets, Bonfire.UI.Common.PlugAttack.Storage}
      )
    end
  end

  # It's possible to customize what happens when conn is let through
  #   def allow_action(conn, _data, _opts), do: conn

  # Or when it's blocked
  def block_action(conn, _data, _opts) do
    conn
    |> Plug.Conn.send_resp(429, "Too many requests, try again later")
    |> Plug.Conn.halt()
  end
end
