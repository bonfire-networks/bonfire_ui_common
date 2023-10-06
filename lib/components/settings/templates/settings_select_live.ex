defmodule Bonfire.UI.Common.SettingsSelectLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, default: []
  prop options, :any, default: []
  prop default_value, :any, default: nil

  prop scope, :any, default: nil

  prop name, :string, default: nil
  prop description, :string, default: nil
  prop label, :string, default: nil

  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> render_sface()
  end
end
