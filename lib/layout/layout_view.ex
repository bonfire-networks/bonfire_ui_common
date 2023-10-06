defmodule Bonfire.UI.Common.LayoutView do
  use Bonfire.UI.Common.Web, :view

  def render("live.html", assigns) do
    Bonfire.UI.Common.LayoutLive.render(assigns)
  end

  def render("root.html", assigns) do
    # TODO: optimised so the [:ui, :theme, :preferred] is only loaded once
    ~H"""
    <!DOCTYPE html>
    <html
      id="root"
      data-open="false"
      class="bg-base-100"
      lang="en"
      data-theme={
        if Settings.get(
             [:ui, :theme, :preferred],
             :system,
             assigns[:__context__] || assigns[:current_user] || @conn
           ) == :bonfire,
           do:
             Settings.get(
               [:ui, :theme, :instance_theme_light],
               "light",
               assigns[:__context__] || assigns[:current_user] || @conn
             ),
           else:
             Settings.get(
               [:ui, :theme, :instance_theme],
               "bonfire",
               assigns[:__context__] || assigns[:current_user] || @conn
             )
      }
      x-data={
        if Settings.get(
             [:ui, :theme, :preferred],
             :system,
             assigns[:__context__] || assigns[:current_user] || @conn
           ) == :system,
           do:
             "{
        prefersDarkTheme: window.matchMedia('(prefers-color-scheme: dark)').matches,
        dark_theme: $el.dataset.theme,
        light_theme: '#{Settings.get([:ui, :theme, :instance_theme_light],
             "light",
             assigns[:__context__] || assigns[:current_user] || @conn)}'
        }"
      }
      x-init={
        if Settings.get(
             [:ui, :theme, :preferred],
             :system,
             assigns[:__context__] || assigns[:current_user] || @conn
           ) == :system,
           do:
             "window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => { prefersDarkTheme = e.matches; });"
      }
      x-bind:data-theme={
        if Settings.get(
             [:ui, :theme, :preferred],
             :system,
             assigns[:__context__] || assigns[:current_user] || @conn
           ) == :system,
           do: "prefersDarkTheme ? dark_theme : light_theme"
      }
    >
      <head>
        <meta charset="utf-8" />

        <Bonfire.UI.Common.SEO.juice item={assigns[:seo] || []} page_title={assigns[:page_title]} />

        <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />

        <%= raw(Bonfire.Common.Config.endpoint_module().include_assets(@conn, :top)) %>

        <%= if assigns[:no_index] do %>
          <meta name="robots" content="noindex" />
        <% end %>

        <%= csrf_meta_tag() %>
      </head>

      <body id="layout-root">
        <%!-- <%= if Code.ensure_loaded?(Thesis.View), do: Thesis.View.thesis_editor(@conn) %> --%>

        <%= @inner_content %>

        <%= raw(Bonfire.Common.Config.endpoint_module().include_assets(@conn, :bottom)) %>
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
