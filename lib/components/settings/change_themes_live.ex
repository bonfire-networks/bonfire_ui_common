defmodule Bonfire.UI.Common.ChangeThemesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: :user
  # prop theme, :string
  # prop theme_light, :string
  # prop scoped, :any, default: nil

  def render(assigns) do
    scoped = Bonfire.Me.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    assigns
    |> assign(
      scoped: scoped,
      preferred: Settings.get([:ui, :theme, :preferred], :system, scoped),
      theme: Settings.get([:ui, :theme, :instance_theme], "bonfire", scoped),
      theme_light: Settings.get([:ui, :theme, :instance_theme_light], "light", scoped),
      themes: Settings.get([:ui, :themes], ["bonfire"], scoped),
      themes_light: Settings.get([:ui, :themes_light], ["bonfire"], scoped)
    )
    |> render_sface()
  end
end
