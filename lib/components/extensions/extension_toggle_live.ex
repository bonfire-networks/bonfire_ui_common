defmodule Bonfire.UI.Common.ExtensionToggleLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop extension, :any, required: true
  prop scope, :any, default: nil
  prop can_instance_wide, :boolean, default: false

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:global_modularity, fn ->
       Config.get([id(assigns) || id(socket.assigns), :modularity], nil)
     end)}
  end
end
