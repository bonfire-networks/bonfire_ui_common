defmodule Bonfire.UI.Common.CodeThemeTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Common.CodeTheme

  @moduletag :backend

  defp keyword_colour(lumis_theme), do: Lumis.Theme.get(lumis_theme).highlights["keyword"].fg

  test "themes without an entry fall back to light-dark() of the light and dark entries" do
    assert CodeTheme.css() =~
             "\n.l-keyword {\n  color: light-dark(#{keyword_colour("bamboo_light")}, #{keyword_colour("bamboo_vulgaris")});"
  end

  test "each Bonfire theme gets its own Lumis theme" do
    css = CodeTheme.css()

    assert css =~
             ~s([data-theme="light"] .l-keyword {\n  color: #{keyword_colour("bamboo_light")};)

    assert css =~
             ~s([data-theme="dark"] .l-keyword {\n  color: #{keyword_colour("bamboo_vulgaris")};)
  end

  test "a theme added to the config gets a block with its Lumis theme" do
    Process.put([:bonfire, :ui, :code_themes], %{
      "light" => "bamboo_light",
      "dark" => "bamboo_vulgaris",
      "bovenjan" => "github_light"
    })

    assert CodeTheme.css() =~
             ~s([data-theme="bovenjan"] .l-keyword {\n  color: #{keyword_colour("github_light")};)
  end
end
