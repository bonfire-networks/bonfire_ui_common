defmodule Bonfire.UI.Common.BasicView do
  use Bonfire.UI.Common.Web, :view

  def render(_, attrs) do
    show_html(attrs[:title], attrs[:body])
  end

  def show_html(title, body, class \\ nil)

  def show_html(title, %{message: details}, class) do
    show_html(title, details, class)
  end

  def show_html(title, body, class) do
    raw("""
    <!DOCTYPE html>
    <html lang="en" class="#{class || "dark"}"  style="background-color: black;">
    <head>
      <meta charset="utf-8"/>
      <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      <meta name="description" content="Bonfire instance">
      <meta name="keywords" content="bonfire, fediverse">
      <meta name="author" content="Bonfire">
      <title data-suffix=" · Bonfire">#{title} · Bonfire</title>
      <link phx-track-static rel='stylesheet' href='/assets/bonfire_basic.css'/>
    </head>

    <body id="layout-root" class="h-screen">
    <div data-phx-main="true">
      <div id="layout-error">
        <div class="">
          <div class="flex flex-col items-center mx-auto mt-16 overflow-hidden">
            <div class="relative z-10 flex justify-between flex-shrink-0">
                <div class="flex items-center flex-shrink-0 lg:px-4">
                  <a data-phx-link="redirect" data-phx-link-state="push" href="/">
                    <div class="flex items-center px-4 py-2 rounded">
                      <div class="w-16 h-20 mb-4 bg-center bg-no-repeat bg-contain" style="background-image: url(#{Config.get([:ui, :theme, :instance_icon], nil)})"></div>
                    </div>
                  </a>
                  <div class="flex flex-1">
                  </div>
                </div>
            </div>
          </div>

          <div class="w-full max-w-screen-md mx-auto mt-12">
            <div class="prose text-center max-w-none" style="color: white;">
              <h1 class="text-base-content">
                #{title}
              </h1>
              <div class="flex flex-col place-content-center">
                #{body}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    </html>
    """)
  end
end
