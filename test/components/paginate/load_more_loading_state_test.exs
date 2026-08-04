defmodule Bonfire.UI.Common.LoadMoreLoadingStateTest do
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Common.LoadMoreLive

  test "full infinite scrolling renders a spinner without flashing the manual label" do
    html = render_load_more(true)

    spinner_classes = classes(html, "[data-id=load_more_spinner]")
    assert "flex" in spinner_classes
    refute "hidden" in spinner_classes

    label_classes = classes(html, "[data-id=load_more_label]")
    assert "hidden" in label_classes

    assert html =~ "Loading more..."
  end

  test "preload mode keeps the manual label until loading starts" do
    html = render_load_more(:preload)

    assert html =~ "Show 3 more"

    spinner_classes = classes(html, "[data-id=load_more_spinner]")
    assert "hidden" in spinner_classes
    assert "phx-scroll-loading:flex" in spinner_classes
    assert "phx-click-loading:flex" in spinner_classes

    label_classes = classes(html, "[data-id=load_more_label]")
    refute "hidden" in label_classes
    assert "phx-scroll-loading:hidden" in label_classes
    assert "phx-click-loading:hidden" in label_classes
  end

  defp classes(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
    |> Floki.attribute("class")
    |> Enum.flat_map(&String.split/1)
  end

  defp render_load_more(infinite_scroll) do
    render_component(&LoadMoreLive.render/1, %{
      cursor: "01KTEST0000000000000000000",
      live_handler: "Bonfire.Social.Feeds",
      context: "test",
      entry_count: 3,
      infinite_scroll: infinite_scroll,
      hide_guest_fallback: true,
      __context__: %{socket_connected?: true, current_url: "/feed/test"}
    })
  end
end
