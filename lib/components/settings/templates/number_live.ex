defmodule Bonfire.UI.Common.Settings.NumberLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, required: true
  prop default_value, :number, default: 0

  prop name, :string, required: true
  prop description, :string, default: nil

  prop unit, :string, default: nil

  prop scope, :any, default: nil

  prop read_only, :boolean, default: false

  prop class, :css_class, default: "input input-sm w-16 input-bordered"

  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    |> render_sface()
  end
end
