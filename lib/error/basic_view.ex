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
          |> Map.put(:class, "bg-base-100 text-base-content")

        _ ->
          assigns
          |> Map.put_new(:class, "")
      end

    assigns = Map.put(assigns, :theme, Bonfire.UI.Common.ThemeHelper.theme_config(assigns))

    ~H"""
    <!DOCTYPE html>
    <html
      lang={Bonfire.Common.Localise.get_locale_id() |> to_string()}
      class={assigns[:class] || "bg-base-100 text-base-content"}
      data-theme={@theme.theme}
      data-theme-mode={@theme.mode}
      data-theme-light={@theme.light}
      data-theme-dark={@theme.dark}
    >
      <head>
        <meta charset="utf-8" />
        <%!-- Resolve the `:system` theme from the device's prefers-color-scheme before paint. --%>
        <script>
          (function() {
            var el = document.documentElement;
            if (el.getAttribute("data-theme-mode") !== "system") return;
            var mq = window.matchMedia("(prefers-color-scheme: dark)");
            el.setAttribute("data-theme", mq.matches ? el.getAttribute("data-theme-dark") : el.getAttribute("data-theme-light"));
          })();
        </script>
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <%!-- viewport-fit=cover matches the main root layout so this fallback page also
              renders edge-to-edge (under the notch/home indicator) in the native app --%>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
        <meta name="description" content="Bonfire instance" />
        <meta name="keywords" content="bonfire, fediverse" />
        <meta name="author" content="Bonfire" />
        <title data-suffix=" · Bonfire">{assigns[:title]} · Bonfire</title>
        <link phx-track-static rel="stylesheet" href="/assets/bonfire_basic.css" />
      </head>

      <body id="layout-root" class="min-h-screen bg-base-100 text-base-content">
        <div data-phx-main="true">
          <div
            id="layout-error"
            class="flex flex-col items-center justify-center min-h-screen px-6 py-16 text-center"
          >
            <a
              data-phx-link="redirect"
              data-phx-link-state="push"
              href="/"
              class="inline-block mb-10 transition-opacity hover:opacity-70"
              aria-label={l("Back to home")}
            >
              <div
                class="w-16 h-16 bg-center bg-no-repeat bg-contain aspect-square"
                style={"background-image: url(#{Config.get([:ui, :theme, :instance_icon], nil)})"}
              >
              </div>
            </a>

            <div class="w-full max-w-md mx-auto">
              <p class="mb-4 text-xs font-semibold tracking-widest uppercase text-primary">
                {assigns[:title]}
              </p>

              <div class="prose max-w-none text-base-content">
                {assigns[:inner_content]}
              </div>

              <div class="mt-10">
                <a
                  data-phx-link="redirect"
                  data-phx-link-state="push"
                  href="/"
                  class="btn btn-primary"
                >
                  {l("Back to home")}
                </a>
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
