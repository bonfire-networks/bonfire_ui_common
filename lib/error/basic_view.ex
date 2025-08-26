defmodule Bonfire.UI.Common.BasicView do
  use Bonfire.UI.Common.Web, :view

  def render(
        key,
        %{conn: %{request_path: "/data/uploads/" <> _ = request_path} = _conn} = assigns
      ) do
    if Path.extname(request_path) in [".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"] do
      ~H"""
      <svg fill="none" height="24" viewBox="0 0 24 24" width="24" xmlns="http://www.w3.org/2000/svg">
        <g stroke="#141b34" stroke-width="1.5">
          <circle cx="16.5" cy="7.5" r="1.5" /><path
            d="m2 14.1354c.66663-.0899 1.3406-.1343 2.01569-.1327 2.85594-.0561 5.64192.7702 7.86081 2.3315 2.058 1.4479 3.504 3.4407 4.1235 5.6658"
            stroke-linejoin="round"
          /><path
            d="m13.5 17.5c1-1 1.6772-1.2232 2.5-1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          /><path d="m20 20.2132c-1.3988 1.2869-3.6365 1.2869-8 1.2869-4.47834 0-6.71751 0-8.10876-1.3912-1.39124-1.3913-1.39124-3.6304-1.39124-8.1088 0-4.36357 0-6.60128 1.28701-8.0001" />
          <g stroke-linecap="round" stroke-linejoin="round">
            <path d="m20.0002 16c.5425 0 1.0478.2945 1.3965.5638.1033-1.1945.1033-2.6813.1033-4.5638 0-4.47834 0-6.71751-1.3912-8.10876-1.3913-1.39124-3.6305-1.39124-8.1088-1.39124-2.40914 0-4.17028 0-5.5.21659" /><path d="m2 2 20 20" />
          </g>
        </g>
      </svg>
      """
    else
      do_render(key, assigns)
    end
  end

  def render(key, assigns) do
    do_render(key, assigns)
  end

  defp do_render(key, assigns) do
    debug(key)
    debug(assigns)

    assigns =
      case key do
        "error.html" ->
          assigns
          |> Map.put(:title, l("Error"))
          |> Map.put(:class, "bg-black")

        _ ->
          assigns
          |> Map.put_new(:class, "")
      end

    ~H"""
    <!DOCTYPE html>
    <html
      lang="en"
      class={assigns[:class] || "bg-black"}
      data-theme={
        if Settings.get(
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
             )
      }
    >
      <head>
        <meta charset="utf-8" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="description" content="Bonfire instance" />
        <meta name="keywords" content="bonfire, fediverse" />
        <meta name="author" content="Bonfire" />
        <title data-suffix=" · Bonfire">{assigns[:title]} · Bonfire</title>
        <link phx-track-static rel="stylesheet" href="/assets/bonfire_basic.css" />
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
                        <div
                          class="w-16 aspect-square h-16 mb-4 bg-center bg-no-repeat bg-contain"
                          style={"background-image: url(#{Config.get([:ui, :theme, :instance_icon], nil)})"}
                        >
                        </div>
                      </div>
                    </a>
                  </div>
                </div>
              </div>

              <div class="w-full max-w-screen-md mx-auto mt-4">
                <div class="prose text-center max-w-none">
                  <div class="flex"><%= assigns[:title] %></div>
                  <div class="flex flex-col place-content-center">
                    {assigns[:inner_content]}
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

  #  <h1 class="text-base-content">
  #               <%= assigns[:title] %>
  #             </h1>
end
