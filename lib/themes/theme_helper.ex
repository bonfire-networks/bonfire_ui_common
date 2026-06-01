defmodule Bonfire.UI.Common.ThemeHelper do
  @moduledoc """
  Helper functions to handle theme selection and application.
  Uses the new OKLCH color format and updated CSS variable naming scheme.
  """
  use Bonfire.Common.Settings
  import Bonfire.Common.Utils, only: [current_user: 1]

  @doc """
  Pushes a `set_theme` event so root.html.heex's listener updates `<html data-theme=…>`.
  No-op for non-binary themes; safe on disconnected sockets (push_event queues until connect).
  """
  def push_theme(socket, theme) when is_binary(theme),
    do: Phoenix.LiveView.push_event(socket, "set_theme", %{theme: theme})

  def push_theme(socket, _), do: socket

  @doc """
  Pushes the current theme for the given socket/assigns, resolving the user's
  preference. For the `:system` preference it pushes the `"system"` sentinel
  along with the configured light/dark theme names so the client can follow the
  device's `prefers-color-scheme` (and keep tracking it live). For fixed
  preferences it pushes the concrete theme name.
  """
  def push_current_theme(socket) do
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
  - Custom theme → fixed `"dark"` base, custom colors applied via inline styles in `layout_live.ex`
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
    case preferred do
      :light -> %{mode: :fixed, theme: light, light: light, dark: dark}
      :dark -> %{mode: :fixed, theme: dark, light: light, dark: dark}
      :custom -> %{mode: :fixed, theme: "dark", light: light, dark: dark}
      :system -> %{mode: :system, theme: dark, light: light, dark: dark}
      _ -> %{mode: :fixed, theme: dark, light: light, dark: dark}
    end
  end
end
