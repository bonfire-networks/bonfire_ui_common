defmodule Bonfire.UI.Common.SettingsToggleLive do
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

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> render_sface()
  end
end
