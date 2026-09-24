defmodule Bonfire.UI.Common.SettingsSelectLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, default: []
  prop options, :any, default: []
  prop default_value, :any, default: nil

  prop scope, :any, default: nil
  prop id, :string, default: nil
  prop name, :string, default: nil
  prop description, :string, default: nil
  prop label, :string, default: nil
  prop label_name, :string, default: nil

  @doc "Places the control beneath its description for settings displayed in a panel grid."
  prop stacked, :boolean, default: false

  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    # a select has no placeholder to show an inherited value in, so with none of its own it shows that one as chosen, rather than its first option
    |> then(fn assigns ->
      if is_nil(assigns[:current_value]),
        do: Map.put(assigns, :current_value, assigns[:inherited_value]),
        else: assigns
    end)
    |> render_sface()
  end
end
