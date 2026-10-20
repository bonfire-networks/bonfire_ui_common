defmodule Bonfire.UI.Common.CarouselArrowsLive do
  @moduledoc "Previous and next buttons for a `CarouselLive` track, for a widget's header. Only from the `sm` breakpoint up, since smaller screens swipe. They are plain data attributes handled by a delegated listener in scroll.js rather than `JS.dispatch`, so they also work on static pages guests get without a LiveView socket."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The `CarouselLive` track's DOM id"
  prop track, :string, required: true

  @doc "How many cards it has: no arrows for one"
  prop count, :integer, default: 0
end
