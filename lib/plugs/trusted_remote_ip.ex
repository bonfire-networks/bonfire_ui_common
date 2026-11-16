defmodule Bonfire.UI.Common.Plugs.TrustedRemoteIp do
  @moduledoc """
  Sets the request's `remote_ip` to the client's address from the forwarding headers (`x-forwarded-for` and the like), but only when the request comes from a trusted proxy: a peer on loopback or a private network (a reverse proxy on the same host or network), or in the CIDR blocks of `config :bonfire_ui_common, :trusted_proxies` (env `TRUSTED_PROXIES`). A client connecting directly from anywhere else keeps its own address, so it cannot pick the address that rate limits and logs see by sending a header.
  """

  @behaviour Plug

  require Bonfire.Common.Config

  @private_networks ~w[127.0.0.0/8 ::1/128 fc00::/7 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
                    |> Enum.map(&RemoteIp.Block.parse!/1)

  @impl Plug
  def init(opts) do
    # the configured proxies are read on every request (a runtime option), so they can change without a restart
    opts
    |> Keyword.put(:proxies, {__MODULE__, :configured_proxies, []})
    |> RemoteIp.init()
  end

  @impl Plug
  def call(conn, opts) do
    if trusted_peer?(conn.remote_ip), do: RemoteIp.call(conn, opts), else: conn
  end

  @doc "The CIDR blocks of the configured trusted proxies."
  def configured_proxies,
    do: Bonfire.Common.Config.get([:bonfire_ui_common, :trusted_proxies], []) |> List.wrap()

  defp trusted_peer?(peer) do
    encoded = RemoteIp.Block.encode(peer)

    Enum.any?(@private_networks, &RemoteIp.Block.contains?(&1, encoded)) or
      Enum.any?(configured_proxies(), fn cidr ->
        case RemoteIp.Block.parse(cidr) do
          {:ok, block} -> RemoteIp.Block.contains?(block, encoded)
          _ -> false
        end
      end)
  end
end
