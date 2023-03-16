defmodule Bonfire.UI.Common.LivePlugs.StaticChanged do
  use Bonfire.UI.Common.Web, :live_plug

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(_, _, socket),
    do: {:ok, assign(socket, :static_changed, static_changed?(socket))}
end
