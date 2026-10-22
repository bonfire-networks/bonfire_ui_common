defmodule Bonfire.UI.Common.CarouselLive do
  @moduledoc "A horizontal carousel of whole cards for widgets: one at a time below `sm` with the next one's edge showing and `visible_items` from `sm` up, scrolled by the `CarouselScroll` hook (scroll.js), with a dot per card. The widget keeps its own header, and puts `CarouselArrowsLive` in it."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The track's DOM id, which `CarouselArrowsLive` and the dots point at"
  prop id, :string, required: true

  prop items, :list, default: []

  @doc "How many whole cards show from the `sm` breakpoint up, always with the next one's edge; one below it"
  prop visible_items, :integer, default: 1

  @doc "Caps each card at `--carousel-tile-max-h` (22rem) and gives clipped ones a show more/less toggle; the card's first child is the tile that gets clipped"
  prop expandable, :boolean, default: false

  @doc "Extra classes for the track, eg. a page's own gutters"
  prop class, :css_class, default: nil

  @doc "One card, given its item"
  slot card, arg: [item: :any]

  @doc """
  The width of each card for `visible_items` whole cards, leaving 1rem of the next one showing past the 0.625rem gaps (`gap-2.5`).

      iex> Bonfire.UI.Common.CarouselLive.card_width(1)
      "calc((100% - 1rem - 1 * 0.625rem) / 1)"

      iex> Bonfire.UI.Common.CarouselLive.card_width(3)
      "calc((100% - 1rem - 3 * 0.625rem) / 3)"
  """
  def card_width(visible_items) when is_integer(visible_items) and visible_items > 0,
    do: "calc((100% - 1rem - #{visible_items} * 0.625rem) / #{visible_items})"

  def card_width(_), do: card_width(1)
end
