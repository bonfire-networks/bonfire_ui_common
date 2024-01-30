defmodule Bonfire.UI.Common.LayoutView do
  use Bonfire.UI.Common.Web, :layout
  # support LVN layout
  use_if_enabled(LiveViewNative.Layouts, env: Application.compile_env!(:bonfire, :env))

  embed_templates "*.html"

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
