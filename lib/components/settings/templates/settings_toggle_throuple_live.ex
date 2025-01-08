defmodule Bonfire.UI.Common.SettingsToggleThroupleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, default: []
  prop scope, :any, default: nil
  prop compact, :boolean, default: false
  prop name, :string, default: nil
  prop description, :string, default: nil
  prop label, :string, default: nil
  prop default_value, :any, default: nil
  prop disabled_value, :any, default: false
  prop enabled_value, :any, default: true
  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil
  prop show_label, :boolean, default: false
  prop with_icon, :boolean, default: false

  prop phx_values, :map, default: %{}

  prop event_name, :string, required: true
  prop event_target, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> maybe_assign_phx_values()
    |> render_sface()
  end

  def maybe_assign_phx_values(assigns) do
    input_name = assigns[:input]
    phx_values = assigns[:phx_values] || %{}

    assigns
    |> assign(
      :phx_values_enabled,
      Map.put(phx_values, "phx-value-#{input_name}", to_string(assigns[:enabled_value]))
    )
    |> assign(
      :phx_values_default,
      Map.put(phx_values, "phx-value-#{input_name}", to_string(assigns[:default_value]))
    )
    |> assign(
      :phx_values_disabled,
      Map.put(phx_values, "phx-value-#{input_name}", to_string(assigns[:disabled_value]))
    )
  end
end
