defmodule Bonfire.UI.Common.ChangeThemesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: :user
  # prop theme, :string
  # prop theme_light, :string
  # prop scoped, :any, default: nil

  def render(assigns) do
    scoped =
      case assigns[:scope] do
        :account -> current_account(assigns[:__context__])
        :instance -> :instance
        _ -> current_user(assigns[:__context__])
      end

    assigns
    |> assign(
      scoped: scoped,
      preferred: Settings.get([:ui, :theme, :preferred], :system, scoped),
      theme: Settings.get([:ui, :theme, :instance_theme], "bonfire", scoped),
      theme_light: Settings.get([:ui, :theme, :instance_theme_light], "light", scoped)
    )
    |> render_sface()
  end
end
