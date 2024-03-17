defmodule Bonfire.UI.Common.ExtensionToggleLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop extension, :any, required: true
  prop scope, :any, default: nil
  prop can_instance_wide, :boolean, default: false

  def update(assigns, socket) do
    extension = id(assigns) || id(socket.assigns)

    global_modularity = Config.get(:modularity, nil, extension)
    # |> debug(extension)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       my_modularity: Settings.get(:modularity, nil, otp_app: extension, context: assigns),
       global_modularity: global_modularity,
       globally_disabled: Bonfire.Common.Extend.disabled_value?(global_modularity)
     )}
  end
end
