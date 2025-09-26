defmodule Bonfire.UI.Common.PlugProtect do
  use PlugAttack
  use Bonfire.Common.Localise
  use Bonfire.Common.Config

  # TODO: consolidate by using Hammer.Plug instead?

  rule "throttle form submissions (using controllers, not LiveView)", conn do
    env = Config.env()
    #  limits the number of form submission that one IP address can make to 5 per minute
    if env != :test and conn.method == "POST" do
      throttle(conn.remote_ip,
        period: 60_000,
        limit: if(env == :dev, do: 90, else: 5),
        storage: {PlugAttack.Storage.Ets, Bonfire.UI.Common.PlugProtect.Storage}
      )
    end
  end

  # It's possible to customize what happens when conn is let through
  #   def allow_action(conn, _data, _opts), do: conn

  # Or when it's blocked
  def block_action(%{path_info: ["login"]} = conn, _data, _opts) do
    # for credential stuffing we don't want to give any hints 
    conn
    |> Plug.Conn.send_resp(403, "Forbidden")
    |> Plug.Conn.halt()
  end

  def block_action(conn, _data, _opts) do
    conn
    |> Plug.Conn.send_resp(429, l("Too many requests, please try again later."))
    |> Plug.Conn.halt()
  end
end
