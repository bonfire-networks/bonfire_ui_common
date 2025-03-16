defmodule Bonfire.UI.Common.ThemeHelper do
  @moduledoc """
  Helper functions to handle theme selection and application.
  Uses the new OKLCH color format and updated CSS variable naming scheme.
  """
  alias Bonfire.Common.Settings

  @doc """
  Determines the current theme based on user preferences and context.
  Handles special cases including:
  - Light/dark preference
  - System preference (follows device settings)
  - Custom theme (which uses inline styles applied via layout_live.ex)

  Returns a theme name string that is set on data-theme attribute in the DOM.
  """
  def current_theme(assigns) do
    context = assigns[:__context__] || assigns[:current_user] || assigns[:conn]

    preferred_theme =
      Settings.get(
        [:ui, :theme, :preferred],
        :system,
        context
      )

    case preferred_theme do
      :custom ->
        # For custom themes, we use "bonfire_custom" as base, and the custom colors
        # are applied via inline CSS variables in layout_live.ex
        "dark"

      :light ->
        Settings.get(
          [:ui, :theme, :instance_theme_light],
          "light",
          context
        )

      :dark ->
        Settings.get(
          [:ui, :theme, :instance_theme],
          "dark",
          context
        )

      :system ->
        # System preference - will be overridden by CSS/JS based on user's device preferences
        # We return a base theme that will be used when system preference can't be determined
        Settings.get(
          [:ui, :theme, :instance_theme],
          "dark",
          context
        )

      _ ->
        # Fallback to default dark theme
        Settings.get(
          [:ui, :theme, :instance_theme],
          "dark",
          context
        )
    end
  end
end
