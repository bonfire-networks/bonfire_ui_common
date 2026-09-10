defmodule Bonfire.UI.Common.ChangeThemesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: nil

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    instance_scope? = assigns[:scope] in [:instance, "instance"]
    custom_key = Bonfire.UI.Common.ThemeHelper.custom_theme_key(assigns[:scope])
    id_prefix = "theme-settings-#{scope_id(assigns[:scope])}"

    # The scope's own overrides are read once and reused by every control. User/account
    # and instance overrides are stored under distinct keys and never mix.
    custom_tokens =
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

    base_theme = Settings.get([:ui, :theme, :instance_theme], "dark", scoped)

    assigns
    |> assign(
      id_prefix: id_prefix,
      # the instance-scope picker sets the default itself, so it can't also follow it
      show_follow_option: !instance_scope?,
      show_accessibility_caution: instance_scope?,
      selected: selected,
      custom_tokens: custom_tokens,
      color_groups: color_groups(),
      radius_groups: radius_groups(),
      # The configured dark theme is the base for custom themes. Only stored overrides
      # are emitted here, exactly as ThemeHelper applies them to the page.
      theme_style: DaisyTheme.style_attr_overrides(custom_tokens),
      theme: base_theme,
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

  defp color_groups do
    [
      %{
        label: l("Base"),
        colors: ["base-100", "base-200", "base-300", "base-content"],
        wrapper_class: "col-span-full mb-2",
        grid_class: "grid-cols-4"
      },
      %{label: l("Primary"), colors: ["primary", "primary-content"]},
      %{label: l("Secondary"), colors: ["secondary", "secondary-content"]},
      %{label: l("Accent"), colors: ["accent", "accent-content"]},
      %{label: l("Neutral"), colors: ["neutral", "neutral-content"]},
      %{label: l("Info"), colors: ["info", "info-content"]},
      %{label: l("Success"), colors: ["success", "success-content"]},
      %{label: l("Warning"), colors: ["warning", "warning-content"]},
      %{label: l("Error"), colors: ["error", "error-content"]}
    ]
  end

  defp radius_groups do
    [
      %{token: "radius-box", label: l("Boxes"), description: l("card, modal, alert")},
      %{token: "radius-field", label: l("Fields"), description: l("input, select, tab")},
      %{
        token: "radius-selector",
        label: l("Selectors"),
        description: l("checkbox, toggle, badge")
      }
    ]
  end

  defp radius_selected?(custom_tokens, token, nil), do: !Map.has_key?(custom_tokens, token)

  defp radius_selected?(custom_tokens, token, radius),
    do: Map.get(custom_tokens, token) == radius
end
