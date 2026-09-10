defmodule Bonfire.UI.Common.CustomThemeColourLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop color, :string
  prop custom_tokens, :map, default: %{}
  prop id_prefix, :string
  prop scope, :any, default: nil
  prop base_theme, :string
  prop theme_style, :string, default: ""

  def render(assigns) do
    color_key = "color-#{assigns.color}"
    saved_color = Map.get(assigns.custom_tokens, color_key)

    assigns
    |> assign(
      color_key: color_key,
      saved_color: saved_color,
      preview_style: preview_style(assigns.color),
      preview_label: preview_label(assigns.color)
    )
    |> render_sface()
  end

  defp preview_style(color) do
    cond do
      color == "base-content" ->
        "background-color: var(--color-base-100); color: var(--color-base-content);"

      String.ends_with?(color, "-content") ->
        base_color = String.replace_suffix(color, "-content", "")

        "background-color: var(--color-#{base_color}); color: var(--color-#{color});"

      true ->
        "background-color: var(--color-#{color}); color: var(--color-base-content);"
    end
  end

  defp preview_label(color) do
    cond do
      String.ends_with?(color, "-content") -> "A"
      String.starts_with?(color, "base-") -> String.replace_prefix(color, "base-", "")
      true -> nil
    end
  end
end
