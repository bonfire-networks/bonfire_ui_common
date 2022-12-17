defmodule Bonfire.UI.Common.PinnedCarouselLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop pins, :list, default: []
  prop title, :string, default: ""
  # prop object_types, :any, default: []
end
