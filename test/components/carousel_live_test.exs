defmodule Bonfire.UI.Common.CarouselLiveTest do
  @moduledoc "The one horizontal carousel the widgets share (Spotlight and group pins, Top discussions, Who to follow, groups, polls closing soon): whole cards, one at a time below `sm` with the next one's edge showing, `visible_items` from `sm` up, dots for where you are, and arrows from `sm` up in the widget's header."
  use Bonfire.UI.Common.ConnCase, async: true
  use Surface.LiveViewTest

  alias Bonfire.UI.Common.CarouselLive

  doctest Bonfire.UI.Common.CarouselLive

  defp carousel(items, visible_items \\ 1) do
    assigns = %{items: items, visible_items: visible_items}

    render_surface do
      ~F"""
      <CarouselLive id="things-track" items={@items} visible_items={@visible_items}>
        <:card :let={item: item}><p data-role="thing">{item}</p></:card>
      </CarouselLive>
      """
    end
    |> Floki.parse_document!()
  end

  defp arrows(count) do
    assigns = %{count: count}

    render_surface do
      ~F"""
      <Bonfire.UI.Common.CarouselArrowsLive track="things-track" count={@count} />
      """
    end
    |> Floki.parse_document!()
  end

  test "each item is a card in the scrolling track, rendered by the caller's slot" do
    doc = carousel(["one", "two", "three"])

    assert [track] = Floki.find(doc, "#things-track")
    assert Floki.attribute(track, "phx-hook") == ["CarouselScroll"]
    assert Floki.find(doc, "#things-track [data-carousel-card] [data-role=thing]") |> length() == 3
  end

  test "visible_items sets how many whole cards show from the sm breakpoint up" do
    style =
      carousel(["one", "two", "three"], 3)
      |> Floki.attribute("[data-carousel-card]", "style")
      |> List.first()

    assert style =~ CarouselLive.card_width(1)
    assert style =~ CarouselLive.card_width(3)
  end

  test "several items get one dot each, pointing at the track" do
    doc = carousel(["one", "two"])

    assert Floki.attribute(doc, "[data-role=carousel_dots]", "data-carousel-dots") == ["things-track"]
    assert Floki.find(doc, "[data-role=carousel_dot]") |> length() == 2
  end

  test "a lone item takes the full width, without dots" do
    doc = carousel(["one"])

    assert Floki.find(doc, "[data-role=carousel_dots]") == []
    assert Floki.attribute(doc, "[data-carousel-card]", "style") |> List.first() =~ "100%"
  end

  test "the arrows control the track, from the sm breakpoint up" do
    doc = arrows(2)

    assert Floki.attribute(doc, "button[data-carousel-scroll]", "data-carousel-scroll") ==
             ["previous", "next"]

    assert Floki.attribute(doc, "button[data-carousel-scroll]", "aria-controls") |> Enum.uniq() ==
             ["things-track"]

    classes = Floki.attribute(doc, "button[data-carousel-scroll]", "class") |> Enum.join(" ")
    assert classes =~ "hidden"
    assert classes =~ "sm:flex"
  end

  test "no arrows for a single item" do
    assert Floki.find(arrows(1), "button[data-carousel-scroll]") == []
  end
end
