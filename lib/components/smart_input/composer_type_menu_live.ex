defmodule Bonfire.UI.Common.ComposerTypeMenuLive do
  @moduledoc "The composer's type picker: a round button with the current type's icon, opening a menu of the types that can be created (note first). Rendered in the header and in the phone top bar; `id_prefix` keeps their ids apart. Renders nothing when only one type is enabled."
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop smart_input_opts, :any, default: nil
  prop id_prefix, :string, default: ""

  def render(assigns) do
    create_object_type = e(assigns[:smart_input_opts], :create_object_type, nil)
    base = LiveHandler.active_smart_input_component(nil, nil)
    active = LiveHandler.active_smart_input_component(nil, create_object_type)

    assigns
    |> assign(:active_icon, LiveHandler.type_icon(active, create_object_type))
    |> assign(:active_label, LiveHandler.type_label(active, create_object_type))
    |> assign(
      :types,
      for component <- [base | LiveHandler.tray_types(base)] do
        %{
          component: component,
          active?: component == active,
          icon: LiveHandler.type_icon(component),
          label: LiveHandler.type_label(component)
        }
      end
    )
    |> render_sface()
  end
end
