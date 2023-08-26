defmodule Bonfire.UI.Common.SettingsToggleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, default: []
  prop scope, :any, default: nil

  prop name, :string, default: nil
  prop description, :string, default: nil
  prop label, :string, default: nil
  prop default_value, :any, default: nil
  prop disabled_value, :any, default: false
  prop enabled_value, :any, default: true
  prop current_value, :any, default: :load_from_settings

  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> update(:input, fn custom_input ->
      custom_input ||
        assigns.keys
        |> Enum.with_index()
        |> Enum.map(fn
          {k, 0} -> "#{k}"
          {k, _} -> "[#{k}]"
        end)

      # |> Enum.reverse() |> Enum.reduce(& "#{&1}[#{&2}]")
    end)
    |> update(:current_value, fn
      :load_from_settings ->
        scoped =
          case assigns[:scope] do
            :account -> current_account(assigns[:__context__])
            :instance -> :instance
            _ -> current_user(assigns[:__context__])
          end

        Bonfire.Me.Settings.get(
          assigns.keys,
          assigns.default_value,
          scoped
        )

      custom_value ->
        custom_value
    end)
    |> render_sface()
  end
end
