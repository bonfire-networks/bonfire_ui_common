defmodule Bonfire.UI.Common.WidgetEditControlsLive do
  @moduledoc """
  Edit mode's tile, standing in for a widget: its name, its setting (`settings:` in `declare_widget`), a drag handle and Remove, over a sketch of its shape. Shown only in edit mode (`widgets-editing`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget, :map, required: true
  prop parent_id, :string, default: nil
  @doc "The setting at `:instance` scope (the instance's default), else the viewer's own."
  prop scope, :any, default: nil

  data settings_id, :string, default: nil
  data setting_label, :string, default: nil

  def render(assigns) do
    assigns
    |> assign(
      settings_id: "#{assigns.parent_id}-#{assigns.widget.id}-settings",
      setting_label:
        setting_label(assigns.widget[:settings], assigns[:__context__], assigns[:scope])
    )
    |> render_sface()
  end

  # from the settings component's optional `current_label/2`
  defp setting_label(module, context, scope) do
    if module && Code.ensure_loaded?(module) && function_exported?(module, :current_label, 2),
      do: module.current_label(context, scope)
  end
end
