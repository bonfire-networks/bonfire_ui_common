defmodule Bonfire.UI.Common.ThemeHelper do
  @moduledoc """
  Helper functions to handle theme selection and application.
  Uses the new OKLCH color format and updated CSS variable naming scheme.
  """
  use Bonfire.Common.Settings
  import Bonfire.Common.Utils, only: [current_user: 1, current_account: 1]

  @doc """
  Pushes a `set_theme` event so root.html.heex's listener updates `<html data-theme=…>`.
  No-op for non-binary themes; safe on disconnected sockets (push_event queues until connect).
  """
  def push_theme(socket, theme) when is_binary(theme),
    do: Phoenix.LiveView.push_event(socket, "set_theme", %{theme: theme})

  def push_theme(socket, _), do: socket

  @doc """
  Applies standard iframe-embed assigns: reads `"theme"` from params, pushes it,
  and sets the layout assigns shared by all embed LiveViews.
  """
  def setup_embed(socket, theme, force_static? \\ false) do
    socket
    |> push_theme(theme)
    |> Phoenix.Component.assign_new(:embed_theme, fn -> theme end)
    |> Phoenix.Component.assign_new(:force_static, fn -> force_static? end)
    |> Phoenix.Component.assign_new(:no_header, fn -> true end)
    |> Phoenix.Component.assign_new(:without_sidebar, fn -> true end)
    |> Phoenix.Component.assign_new(:without_secondary_widgets, fn -> true end)
    |> Phoenix.Component.assign_new(:sidebar_widgets, fn -> [] end)
  end

  @doc """
  Pushes the current theme for the given socket/assigns, resolving the user's
  preference. For the `:system` preference it pushes the `"system"` sentinel
  along with the configured light/dark theme names so the client can follow the
  device's `prefers-color-scheme` (and keep tracking it live). For fixed
  preferences it pushes the concrete theme name.
  """
  def push_current_theme(socket) do
    socket
    |> push_base_theme()
    # root.html.heex isn't reactive, so push the custom palette to <html> (empty clears it)
    |> Phoenix.LiveView.push_event("set_custom_theme", %{style: custom_theme_style(socket)})
  end

  defp push_base_theme(socket) do
    case theme_config(socket) do
      %{mode: :system, light: light, dark: dark} ->
        Phoenix.LiveView.push_event(socket, "set_theme", %{
          theme: "system",
          light: light,
          dark: dark
        })

      %{theme: theme} ->
        push_theme(socket, theme)
    end
  end

  @doc """
  The custom theme's CSS variable declarations (`--color-base-100: #fff; …`) when a
  custom palette is active, otherwise an empty string.

  Set as an inline `style` on `<html>` in root.html.heex and pushed via `set_custom_theme`
  for live updates.

  The user's and the instance's palettes are stored under distinct keys (see
  `custom_theme_key/1`) and never mix:
  - a user/account that explicitly chose the `:custom` mode gets *their own* palette only;
  - anyone following the instance default (no explicit choice of their own, including
    guests) gets the *instance* palette when the instance's mode is `:custom`.
  """
  def custom_theme_style(assigns) do
    user = current_user(assigns)
    account = current_account(assigns)
    context = user || account || Map.get(assigns, :conn)

    case own_theme_preference(user) || own_theme_preference(account) do
      :custom ->
        # only set variables (not merged defaults), so unset ones follow the base theme
        Settings.get([:ui, :theme, :custom], %{}, context)
        |> normalize_palette()
        |> DaisyTheme.style_attr_overrides()

      nil ->
        if normalize_preference(Settings.get([:ui, :theme, :preferred], nil, context)) ==
             :custom do
          Settings.get([:ui, :theme, :custom_instance], %{}, context)
          |> normalize_palette()
          |> DaisyTheme.style_attr_overrides()
        else
          ""
        end

      _other_fixed_preference ->
        ""
    end
  end

  @doc """
  The theme mode explicitly chosen by the given scope alone (a user or account),
  ignoring values inherited from other scopes — `nil` means the scope has no choice
  of its own and follows the instance default.
  """
  def own_theme_preference(nil), do: nil

  def own_theme_preference(scoped) do
    # `preload: true` so `nil` reliably means "no own preference" rather than "settings
    # assoc wasn't loaded": a loaded assoc is used as-is (no query), an unloaded one is
    # fetched — otherwise a scope struct without preloaded settings would wrongly read as
    # following the instance and drop the user's chosen theme (mirrors the write path)
    Settings.__get__(
      [:ui, :theme, :preferred],
      nil,
      Bonfire.Common.Opts.to_options(scoped)
      |> Keyword.merge(one_scope_only: true, preload: true)
    )
    |> normalize_preference()
  end

  defp normalize_palette(palette) when is_map(palette) or is_list(palette),
    do: Bonfire.Common.Enums.stringify_keys(palette)

  defp normalize_palette(_), do: %{}

  @doc """
  The settings key under which a custom palette is stored for the given scope.

  User and instance palettes use distinct keys so they stay independent — settings
  merge across scopes, so a shared key would blend a user's colours with the instance's.
  """
  def custom_theme_key(scope) when scope in [:instance, "instance"], do: :custom_instance
  def custom_theme_key(_scope), do: :custom

  @doc """
  Determines the current theme based on user preferences and context.

  Returns the concrete theme name string used as the server-rendered (and
  JS-disabled) fallback for the `data-theme` attribute. For the `:system`
  preference this is only a fallback — the actual theme is resolved client-side
  from `prefers-color-scheme` (see `theme_config/1` and `root.html.heex`).
  """
  def current_theme(assigns), do: theme_config(assigns).theme

  @doc """
  Resolves the full theme configuration for the given assigns/socket.

  Returns a map with:
  - `:mode` — `:system` (follow device `prefers-color-scheme`) or `:fixed`
  - `:theme` — concrete theme name for the SSR/no-JS `data-theme` fallback
  - `:light` / `:dark` — instance light/dark theme names the client switches between

  Handles special cases:
  - Light/dark preference → fixed
  - System preference → follows device settings client-side (dark as no-JS fallback)
  - Custom theme → fixed dark/base theme, custom colors applied via inline styles in `layout_live.ex`
  """
  def theme_config(assigns) do
    # `Map.get/2` (not Access) so a `%Phoenix.LiveView.Socket{}` passed from the
    # push paths doesn't crash — it simply has no `:conn` key.
    context = current_user(assigns) || Map.get(assigns, :conn)

    preferred = Settings.get([:ui, :theme, :preferred], :system, context)
    light = Settings.get([:ui, :theme, :instance_theme_light], "light", context)
    dark = Settings.get([:ui, :theme, :instance_theme], "dark", context)

    resolve_theme_config(preferred, light, dark)
  end

  @doc """
  Maps a theme preference and the instance light/dark theme names to a resolved config map.

  Kept pure (no settings/context lookup) so the resolution logic is easy to test.

  ## Examples

      iex> Bonfire.UI.Common.ThemeHelper.resolve_theme_config(:light, "light", "dark")
      %{mode: :fixed, theme: "light", light: "light", dark: "dark"}

      iex> Bonfire.UI.Common.ThemeHelper.resolve_theme_config(:dark, "light", "dark")
      %{mode: :fixed, theme: "dark", light: "light", dark: "dark"}

      iex> Bonfire.UI.Common.ThemeHelper.resolve_theme_config(:custom, "light", "dark")
      %{mode: :fixed, theme: "dark", light: "light", dark: "dark"}

      iex> Bonfire.UI.Common.ThemeHelper.resolve_theme_config(:system, "light", "dark")
      %{mode: :system, theme: "dark", light: "light", dark: "dark"}
  """
  def resolve_theme_config(preferred, light, dark) do
    preferred = normalize_preference(preferred)
    light = normalize_theme_name(light, "light")
    dark = normalize_theme_name(dark, "dark")

    case preferred do
      :light -> %{mode: :fixed, theme: light, light: light, dark: dark}
      :dark -> %{mode: :fixed, theme: dark, light: light, dark: dark}
      :custom -> %{mode: :fixed, theme: dark, light: light, dark: dark}
      :system -> %{mode: :system, theme: dark, light: light, dark: dark}
      _ -> %{mode: :fixed, theme: dark, light: light, dark: dark}
    end
  end

  defp normalize_preference(preferred) when preferred in [:light, :dark, :custom, :system],
    do: preferred

  defp normalize_preference("light"), do: :light
  defp normalize_preference("dark"), do: :dark
  defp normalize_preference("custom"), do: :custom
  defp normalize_preference("system"), do: :system
  defp normalize_preference(preferred), do: preferred

  defp normalize_theme_name(theme, fallback) when is_binary(theme) do
    if theme == "" do
      fallback
    else
      theme
    end
  end

  defp normalize_theme_name(theme, _fallback) when is_atom(theme) and not is_nil(theme),
    do: Atom.to_string(theme)

  defp normalize_theme_name(_theme, fallback), do: fallback
end
