defmodule Bonfire.UI.Common.LayoutView do
  use Bonfire.UI.Common.Web, :view

  def render("live.html", assigns) do
    Bonfire.UI.Common.LayoutLive.render(assigns)
  end

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html
      id="root"
      data-open="false"
      class="bg-base-300"
      lang="en"
      data-theme={
        Settings.get(
          [:ui, :theme, :instance_theme],
          "bonfire",
          assigns[:__context__] || assigns[:current_user] || @conn
        )
      }
    >
      <head>
        <meta charset="utf-8" />

        <Bonfire.UI.Common.SEO.juice item={assigns[:seo] || []} page_title={assigns[:page_title]} />

        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <%= raw(Config.get!(:endpoint_module).include_assets(@conn, :top)) %>

        <%= if assigns[:no_index] do %>
          <meta name="robots" content="noindex" />
        <% end %>

        <%= csrf_meta_tag() %>
      </head>
      <body id="layout-root">
        <style>
          .shadow {
            box-shadow: 0 1px 2px rgba(0,0,0,.2)
          }
        </style>
        <%= if Code.ensure_loaded?(Thesis.View), do: Thesis.View.thesis_editor(@conn) %>

        <%= @inner_content %>

        <%= raw(Config.get!(:endpoint_module).include_assets(@conn, :bottom)) %>
      </body>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end
end
