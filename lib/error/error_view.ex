defmodule Bonfire.UI.Common.ErrorView do
  use Bonfire.UI.Common.Web, :view

  @codes %{
    403=> "Not allowed",
    404=> "Not found",
    500=> "Something went wrong"
  }

  def render("403.html", assigns) do
    show_error(403, reason(assigns)<>"<p><img src='https://media.sciencephoto.com/image/c0021814/800wm'/>", true)
  end

  def render("404.html", %{conn: %{assigns: %{reason: %{conn: %{params: %{"LiveHandler" => live_handler} = params} = conn}}}}) do
    debug(params, "404 params")
    with %{title: title, body: body} <- Bonfire.UI.Common.FormsLiveHandlerFallbackController.handle_fallback(live_handler, params, conn) do
      show_html(title, body)
    end
  end
  def render("404.html", _assigns) do
    # debug(assigns, "404 assigns")
    show_html(404, "<img src='https://i.pinimg.com/originals/98/8d/ef/988def4abdcba22f2c9e907d041a56ce.gif'/>")
  end

  def render("500.html", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins.")<>"<p><img class='mx-auto' src='https://media2.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.gif'/>", true)
  end

  def render("app.html", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins."), true)
  end

  def render("403.activity+json", assigns) do
    show_error(403, reason(assigns), false)
  end
  def render("404.activity+json", _assigns) do
    show_error(404, nil, false)
  end
  def render("500.activity+json", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins."), false)
  end

  def render("403.json", assigns) do
    show_error(403, reason(assigns), false)
  end
  def render("404.json", _assigns) do
    show_error(404, nil, false)
  end
  def render("500.json", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins."), false)
  end

  defp show_error(error_or_error_code, details, as_html?) do
    error(details)

    if as_html?, do: show_html(error_or_error_code, details),
    else: Jason.encode!(%{
      "errors"=> [
        %{
          "status"=> (if is_number(error_or_error_code), do: error_or_error_code, else: 500),
          "title"=> @codes[error_or_error_code] || error_or_error_code,
          "detail"=> details
        }
      ]
    })
  end

  defp reason(%{reason: reason}), do: reason(reason)
  defp reason(%{message: reason}), do: reason
  defp reason(reason) when is_binary(reason), do: reason
  defp reason(reason) when not is_map(reason), do: inspect reason
  defp reason(_), do: nil

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # 404.
  def template_not_found(template, assigns) do
    warn(template, "No template defined for")
    show_error(Phoenix.Controller.status_message_from_template(template), Map.get(assigns, :reason, "Unknown Error"), true)
  end

  def show_html(error_code, details) when is_integer(error_code), do: show_html(@codes[error_code], details)
  def show_html(error, details) do
    Bonfire.UI.Common.BasicView.show_html(error, details)
  end
end
