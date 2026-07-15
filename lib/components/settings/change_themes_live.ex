defmodule Bonfire.UI.Common.ChangeThemesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: nil
  # prop theme, :string
  # prop theme_light, :string
  # prop scoped, :any, default: nil

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    instance_scope? = assigns[:scope] in [:instance, "instance"]
    custom_key = Bonfire.UI.Common.ThemeHelper.custom_theme_key(assigns[:scope])
    id_prefix = "theme-settings-#{scope_id(assigns[:scope])}"

    # the scope's own palette, read once and reused by every swatch in the template
    # (user/account and instance palettes are stored under distinct keys and never mix)
    custom_colors =
      Settings.get([:ui, :theme, custom_key], %{}, scoped)
      |> Bonfire.Common.Enums.stringify_keys()

    # the mode chosen in THIS scope only — :instance_default means no choice of its
    # own, so the instance's settings cascade through (the default for new users)
    selected =
      if instance_scope? do
        Settings.get([:ui, :theme, :preferred], :system, scoped)
      else
        Bonfire.UI.Common.ThemeHelper.own_theme_preference(scoped) || :instance_default
      end

    assigns
    |> assign(
      scoped: scoped,
      custom_key: custom_key,
      id_prefix: id_prefix,
      # the instance-scope picker sets the default itself, so it can't also follow it
      show_follow_option: !instance_scope?,
      selected: selected,
      custom_colors: custom_colors,
      display_theme: DaisyTheme.theme(custom_colors),
      # scope the editor's swatch previews (which use `var(--color-…)`) to the palette
      # being edited, not the page's applied theme
      theme_style: DaisyTheme.style_attr(custom_colors),
      theme: Settings.get([:ui, :theme, :instance_theme], "dark", scoped),
      theme_light: Settings.get([:ui, :theme, :instance_theme_light], "light", scoped),
      themes: Settings.get([:ui, :themes_dark], ["dark"], scoped),
      themes_light: Settings.get([:ui, :themes_light], ["light"], scoped)
    )
    |> render_sface()
  end

  defp scope_id(nil), do: "user"
  defp scope_id(scope) when is_atom(scope), do: scope |> Atom.to_string() |> scope_id()

  defp scope_id(scope) when is_binary(scope) do
    String.replace(scope, ~r/[^a-zA-Z0-9_-]/, "-")
  end

  defp scope_id(_), do: "scoped"
end
