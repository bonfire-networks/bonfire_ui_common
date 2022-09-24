defmodule Bonfire.UI.Common.LivePlugs.StaticChanged do
  use Bonfire.UI.Common.Web, :live_plug

  def mount(_, _, socket),
    do: {:ok, assign(socket, :static_changed, static_changed?(socket))}
end
