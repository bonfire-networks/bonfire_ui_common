defmodule Bonfire.UI.Common.SettingsTextareaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, required: true
  prop default_value, :any, default: nil
  prop hidden, :boolean, default: false

  prop name, :string, required: true
  prop description, :string, default: nil
  prop placeholder, :string, default: ""

  prop scope, :any, default: nil

  prop read_only, :boolean, default: false

  @doc "Turn off to put several inputs in one form, with a single button of its own to save them all."
  prop submit_button, :boolean, default: true

  prop class, :css_class, default: "input w-16"

  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> render_sface()
  end
end
