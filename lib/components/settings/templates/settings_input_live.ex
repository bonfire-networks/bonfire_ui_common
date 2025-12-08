defmodule Bonfire.UI.Common.SettingsInputLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, required: true
  prop default_value, :string, default: nil
  prop hidden, :boolean, default: false
  prop name, :string, required: true
  prop description, :string, default: nil
  prop placeholder, :string, default: ""

  prop scope, :any, default: nil

  prop read_only, :boolean, default: false

  prop class, :css_class, default: "input w-16"

  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> render_sface()
  end
end
