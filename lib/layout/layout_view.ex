defmodule Bonfire.UI.Common.LayoutView do
  use Bonfire.UI.Common.Web, {:layout_view, [namespace: Bonfire.UI.Common]}

  def render("live.html", assigns) do
    Bonfire.UI.Common.LayoutLive.page(assigns)
  end
end
