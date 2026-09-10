defmodule Bonfire.UI.Common.CustomThemeColourLiveTest do
  use Bonfire.UI.Common.DataCase, async: true

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Common.CustomThemeColourLive

  setup do
    {:ok, user: fake_user!()}
  end

  test "an unset colour is labelled as inherited from its base theme", %{user: user} do
    document =
      render_colour(user,
        color: "primary",
        custom_tokens: %{},
        base_theme: "jacobin"
      )

    assert Floki.text(document) =~ "Inherited"
    assert Floki.attribute(document, "button", "aria-label") == ["Select color for primary"]

    assert Floki.attribute(document, "[data-color=color-primary]", "style") ==
             ["background-color: var(--color-primary); color: var(--color-base-content)"]
  end

  test "a stored colour value replaces the inherited label", %{user: user} do
    document =
      render_colour(user,
        color: "primary-content",
        custom_tokens: %{"color-primary-content" => "#abcdef"},
        base_theme: "dark"
      )

    assert Floki.text(document) =~ "#abcdef"
    refute Floki.text(document) =~ "Inherited"
    assert Floki.attribute(document, "[data-color=color-primary-content]", "style") ==
             ["background-color: var(--color-primary); color: var(--color-primary-content)"]
  end

  defp render_colour(user, overrides) do
    defaults = [
      color: "primary",
      custom_tokens: %{},
      id_prefix: "theme-settings-user",
      scope: "user",
      base_theme: "dark",
      theme_style: "",
      __context__: %{current_user: user}
    ]

    render_component(&CustomThemeColourLive.render/1, Keyword.merge(defaults, overrides))
    |> Floki.parse_fragment!()
  end
end
