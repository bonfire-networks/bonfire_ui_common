defmodule Bonfire.UI.Common.ThemeHelper do
  def current_theme(assigns) do
    context = assigns[:__context__] || assigns[:current_user] || assigns[:conn]

    preferred_theme =
      Bonfire.Common.Settings.get(
        [:ui, :theme, :preferred],
        :system,
        context
      )

    theme_key =
      case preferred_theme do
        :light -> [:ui, :theme, :instance_theme_light]
        _ -> [:ui, :theme, :instance_theme]
      end

    Bonfire.Common.Settings.get(
      theme_key,
      default_theme(preferred_theme),
      context
    )
  end

  defp default_theme(:light), do: "light"
  defp default_theme(_), do: "dark"
end
