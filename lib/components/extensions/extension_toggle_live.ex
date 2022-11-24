defmodule Bonfire.UI.Common.ExtensionToggleLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop extension, :any, required: true
  prop scope, :atom, default: nil
  prop required_deps, :list, default: []
  prop can_instance_wide, :boolean, default: false

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
