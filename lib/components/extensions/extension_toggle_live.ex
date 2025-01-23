defmodule Bonfire.UI.Common.ExtensionToggleLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop extension, :any, required: true
  prop scope, :any, default: nil
  prop can_instance_wide, :boolean, default: false
  prop show_explanation, :boolean, default: false

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    extension = id(assigns(socket))

    global_modularity = Config.get(:modularity, nil, extension)
    # |> debug(extension)

    my_modularity =
      Settings.get(:modularity, nil, otp_app: extension, context: assigns(socket)[:__context__])

    {:ok,
     socket
     |> assign(
       #  my_modularity: my_modularity,
       my_disabled?: Bonfire.Common.Extend.disabled_value?(my_modularity),
       #  global_modularity: global_modularity,
       globally_disabled?: Bonfire.Common.Extend.disabled_value?(global_modularity)
     )}
  end

  def toggle_status(my_disabled?) do
    if my_disabled?, do: l("Disabled for me"), else: l("Enabled for me")
  end
end
