defmodule Bonfire.UI.Common.LayoutView do
  use Bonfire.UI.Common.Web, :layout

  embed_templates "*.html"

  use_if_enabled(Bonfire.UI.Common.Web.Native, :layout)

  # def render("live.html", assigns) do
  #   Bonfire.UI.Common.LayoutLive.render(assigns)
  # end

  # def render("live_swiftui.html", assigns) do
  #   Bonfire.UI.Common.LayoutLive.render(assigns)
  # end

  # def render("app.html", assigns) do
  #   ~H"""
  #   <%= @inner_content %>
  #   """
  # end
end
