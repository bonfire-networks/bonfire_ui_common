defmodule Bonfire.UI.Common.PageHeaderLiveTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Common.PageHeaderLive

  defp render_header(assigns),
    do:
      render_component(
        &PageHeaderLive.render/1,
        Map.merge(
          %{page_title: "Discussion", show_right_actions: false, __context__: %{}},
          Map.new(assigns)
        )
      )

  test "a title context reads as \"<title> in <place>\", linking to the place" do
    html =
      render_header(
        page_title_context: %{
          name: "gmfarcaster",
          path: "/&gmfarcaster",
          icon_url: "https://example.com/gm.png"
        }
      )

    assert html =~ "Discussion"
    assert html =~ ~s(data-role="page_title_context")
    assert html =~ ~s(href="/&amp;gmfarcaster")
    assert html =~ "gmfarcaster"
    assert html =~ ~s(src="https://example.com/gm.png")
  end

  test "without a title context the title stays on its own" do
    html = render_header([])

    assert html =~ "Discussion"
    refute html =~ ~s(data-role="page_title_context")
  end
end
