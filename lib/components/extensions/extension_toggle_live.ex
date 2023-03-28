defmodule Bonfire.UI.Common.ExtensionToggleLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop extension, :any, required: true
  prop scope, :atom, default: nil
  prop can_instance_wide, :boolean, default: false

  def update(assigns, socket) do
    {:noreply,
     socket
     |> assign(assigns)
     |> assign_new(:globally_disabled, fn ->
       Config.get([id(assigns) || id(socket.assigns), :disabled], nil)
     end)}
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
