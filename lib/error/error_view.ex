defmodule Bonfire.UI.Common.ErrorView do
  use Bonfire.UI.Common.Web, :view

  def render("403.html", assigns) do
    show_error(
      403,
      reason(assigns),
      true,
      "<p><img src='https://media.sciencephoto.com/image/c0021814/800wm'/>"
    )
  end

  def render("404.html", %{
        conn: %{
          assigns: %{
            reason: %{
              conn: %{params: %{"LiveHandler" => live_handler} = params} = conn
            }
          }
        }
      }) do
    debug(params, "404 params")

    with %{title: title, body: body} <-
           Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller.handle_fallback(
             live_handler,
             params,
             conn
           ) do
      show_html(title, body)
    end
  end

  def render("404.html", _assigns) do
    # debug(assigns, "404 assigns")
    show_html(
      404,
      "<img src='https://i.pinimg.com/originals/98/8d/ef/988def4abdcba22f2c9e907d041a56ce.gif'/>",
      "bg-black"
    )
  end

  def render("500.html", %{reason: %{reason: :queue_timeout}} = assigns) do
    render("503.html", assigns)
  end

  def render("401.html", %{reason: %{code: :needs_login, message: message} = _reason} = _assigns) do
    debug("show login form")
    assigns = %{form: Bonfire.UI.Me.LoginController.form_cs(), title: message}
    # Bonfire.UI.Me.LoginLive.custom_render()
    # Bonfire.UI.Me.LoginViewLive.render(assigns)
    ~H"""
    <h1 class="text-base-content">
      {@title}
    </h1>
    <Bonfire.UI.Me.LoginViewLive.render form={@form} error={nil} __context__={%{}} />
    """
  end

  def render("500.html", assigns) do
    debug(assigns)

    show_error(
      500,
      reason(assigns) || l("Please try again or contact the instance admins."),
      true,
      "\n<p><img class='mx-auto h-[300px]' src='https://media1.giphy.com/media/Z1BTGhofioRxK/giphy.gif'/>"
    )
  end

  def render("503.html", _assigns) do
    show_error(
      503,
      l("Please try again in a few minutes or contact the instance admins."),
      true,
      "\n<p><img class='mx-auto h-[300px]' src='https://images.newrepublic.com/5c45fedc6977c22a8607892b8918c22ee8394bea.jpeg'/>"
    )
  end

  def render("403.activity+json", assigns) do
    show_error(403, reason(assigns), false)
  end

  def render("404.activity+json", _assigns) do
    show_error(404, nil, false)
  end

  def render("409.activity+json", assigns) do
    show_error(409, reason(assigns), false)
  end

  def render("500.activity+json", assigns) do
    show_error(
      500,
      reason(assigns) || l("Please try again or contact the instance admins."),
      false
    )
  end

  def render("403.json", assigns) do
    show_error(403, reason(assigns), false)
  end

  def render("404.json", _assigns) do
    show_error(404, nil, false)
  end

  def render("500.json", assigns) do
    show_error(
      500,
      reason(assigns) || l("Please try again or contact the instance admins."),
      false
    )
  end

  def render(:app, assigns) do
    render("app.html", assigns)
  end

  def render("app.html", assigns) do
    show_error(
      assigns["code"] || 500,
      reason(assigns) || l("Please try again or contact the instance admins."),
      true
    )
  end

  def render(other, assigns) do
    warn(other)
    render("app.html", assigns)
  end

  defp show_error(error_or_error_code, details, as_html?, _extra_html \\ nil) do
    http_code =
      Types.maybe_to_integer(error_or_error_code, 500)
      |> debug(error_or_error_code)

    error(details)

    {codename, msg} = Bonfire.Fail.get_error_tuple(http_code) || {nil, error_or_error_code}

    if as_html? do
      show_html(msg || error_or_error_code, details)
    else
      Jason.encode!(%{
        "errors" => [
          %{
            "status" => http_code,
            "code" => codename,
            "title" => msg || error_or_error_code,
            "detail" => details
          }
        ]
      })
    end
  end

  defp reason(%{reason: reason}), do: reason(reason)
  defp reason(%{message: reason}), do: reason
  defp reason(reason) when is_binary(reason), do: Text.text_only(reason)
  defp reason(reason) when is_atom(reason), do: Bonfire.Fail.get_error_msg(reason) || reason
  defp reason(reason) when not is_map(reason), do: inspect(reason)

  defp reason(_other) do
    # debug(other)
    nil
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # 404.
  def template_not_found(template, assigns) do
    warn(template, "No template defined for")

    show_error(
      Phoenix.Controller.status_message_from_template(template),
      Map.get(assigns, :reason, "Unknown Error"),
      false
    )
  end

  def show_html(error_code, details, class \\ nil)

  def show_html(http_code, details, class) when is_integer(http_code) do
    {_name, msg} = Bonfire.Fail.get_error_tuple(http_code) || {nil, "#{http_code} error"}
    show_html(msg, details, class)
  end

  def show_html(error, %{message: details}, class) do
    show_html(error, details, class)
  end

  def show_html(error, details, class) do
    assigns = %{title: Text.text_only(error), details: details, class: class}

    ~H"""
    <h1 class="text-base-content">
      {@title}
    </h1>
    {if Bonfire.Common.Config.env() != :prod do
      raw(to_string(@details))
    end}
    """
  end

  # def show_html(title, body, class \\ nil)

  # def show_html(title, %{message: details}, class) do
  #   show_html(title, details, class)
  # end

  # def show_html(title, body, class) do
  #   Bonfire.UI.Common.BasicView.render(Bonfire.UI.Common.BasicView, %{title: title, inner_content: body, class: class})
  # end
end
