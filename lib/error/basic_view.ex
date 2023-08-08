defmodule Bonfire.UI.Common.BasicView do
  use Bonfire.UI.Common.Web, :view

  def render(key, assigns) do
    debug(key)
   # debug(assigns)
    
    assigns = case key do
      "error.html" -> Map.put(assigns, :title, l "Error")
      _ -> assigns
  end

  ~H"""
    <!DOCTYPE html>
    <html lang="en" class={"#{assigns[:class] || "dark"}"}  data-theme={if Settings.get(
      [:ui, :theme, :preferred],
      :system,
      assigns[:__context__] || assigns[:current_user] || @conn
    ) == :light,
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
      )}>
    <head>
      <meta charset="utf-8"/>
      <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      <meta name="description" content="Bonfire instance">
      <meta name="keywords" content="bonfire, fediverse">
      <meta name="author" content="Bonfire">
      <title data-suffix=" · Bonfire"><%= assigns[:title] %> · Bonfire</title>
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
                      <div class="w-16 h-20 mb-4 bg-center bg-no-repeat bg-contain" style={"background-image: url(#{Config.get([:ui, :theme, :instance_icon], nil)})"}></div>
                    </div>
                  </a>
                  <div class="flex flex-1">
                  </div>
                </div>
            </div>
          </div>

          <div class="w-full max-w-screen-md mx-auto mt-4">
            <div class="prose text-center max-w-none">
              <%!-- <h1 class="text-base-content">
                <%= assigns[:title] %>
              </h1> --%>
              <div class="flex flex-col place-content-center">
                <%= assigns[:inner_content] %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    </body>
    </html>
    """
  
  end


end
