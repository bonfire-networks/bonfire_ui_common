defmodule Bonfire.UI.Common.BasicView do
  use Bonfire.UI.Common.Web, :view

  def render(_, attrs) do
    show_html(attrs[:title], attrs[:body])
  end

  def show_html(title, body) do
    raw """
    <!DOCTYPE html>
    <html lang="en" class="dark">
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
            <div class="relative z-10 flex justify-between flex-shrink-0 h-16">
                <div class="flex items-center flex-shrink-0 lg:px-4">
                  <a data-phx-link="redirect" data-phx-link-state="push" href="/">
                    <div class="flex items-center px-4 py-2 rounded">
                      <div class="w-12 h-12 mb-4 bg-center bg-no-repeat bg-contain" style="background-image: url(https://bonfirenetworks.org/img/bonfire.png)"></div>
                    </div>
                  </a>
                  <div class="flex flex-1">
                  </div>
                </div>
            </div>
          </div>

          <div class="mx-auto mt-12">
            <div class="prose text-center">
              <h1 class="text-base-content">
                #{title}
              </h1>
              #{body}
            </div>
          </div>
        </div>
      </div>
    </div>
    </html>
    """
  end
end
