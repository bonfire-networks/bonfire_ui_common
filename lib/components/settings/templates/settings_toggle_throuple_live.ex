defmodule Bonfire.UI.Common.SettingsToggleThroupleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, default: []
  prop scope, :any, default: nil
  prop compact, :boolean, default: false
  prop name, :string, default: nil
  prop description, :string, default: nil
  prop icon, :any, default: nil
  prop default_value, :any, default: nil
  prop disabled_value, :any, default: false
  prop enabled_value, :any, default: true
  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil
  prop with_icons, :boolean, default: false

  @doc "What each segment says, for a choice that is not yes/default/no"
  prop label_yes, :string, default: nil
  prop label_default, :string, default: nil
  prop label_no, :string, default: nil

  @doc "Shows the segments as no, default, yes. Reordered in the markup rather than by CSS, so keyboard focus moves the way the segments read"
  prop reversed, :boolean, default: false

  prop phx_values, :map, default: %{}

  @doc "What the yes and no segments send"
  prop event_name, :string, default: "Bonfire.Common.Settings:set"

  @doc "What the middle segment sends, given the `keys`: removing the setting, so whatever applies without a choice applies again, rather than storing a blank that would count as a choice. Pass `nil` to have it send `event_name` with `default_value` instead"
  prop unset_event_name, :string, default: "Bonfire.Common.Settings:delete"
  prop event_target, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> maybe_assign_phx_values()
    |> render_sface()
  end

  @doc "The segments in the order they are shown"
  def segments(true), do: [:disabled, :default, :enabled]
  def segments(_), do: [:enabled, :default, :disabled]

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
