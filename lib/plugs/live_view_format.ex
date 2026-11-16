defmodule Bonfire.UI.Common.Plugs.LiveViewFormat do
  @moduledoc """
  A LiveView page renders only as HTML, whatever format the `Accept` header negotiated (`:browser_accepts` lists formats such as `text` and `xml` for the controllers that serve them). Any other format would reach `Plug.Conn.send_resp/3` as an unencoded `{:safe, iodata}` and crash.

  When the client asked for `text` or `mjml`, the page renders the way `?_email_format=` shows it: each component with an email template renders that inside the HTML page. This plug puts `"_email_format"` in `conn.params`, which a routed LiveView gets as its params and a controller copies into `current_params`. Such a response must not be kept by a shared cache, see `email_mode?/1`.

  Plug it after `accepts` in a router pipeline. Controllers call `live_render/3` from this module instead of `Phoenix.LiveView.Controller`'s (the `:controller` quote in `Bonfire.UI.Common.Web` imports it).
  """

  @email_formats ["text", "mjml"]

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> maybe_put_email_format()
    |> html_if_live_view()
  end

  @doc "Renders a LiveView from a controller, as HTML. Takes the same arguments as `Phoenix.LiveView.Controller.live_render/3`."
  def live_render(conn, view, opts \\ []) do
    conn
    |> put_html_format()
    |> Phoenix.LiveView.Controller.live_render(view, opts)
  end

  @doc "Whether the page renders its components as emails (`?_email_format=`, or a client that asked for plain text), which a shared cache must not keep for the URL."
  def email_mode?(%{params: %{"_email_format" => _}}), do: true
  def email_mode?(_), do: false

  defp maybe_put_email_format(%{params: %{"_email_format" => _}} = conn), do: conn

  defp maybe_put_email_format(%{params: %{} = params} = conn) do
    case Phoenix.Controller.get_format(conn) do
      format when format in @email_formats ->
        %{conn | params: Map.put(params, "_email_format", format)}

      _ ->
        conn
    end
  end

  defp maybe_put_email_format(conn), do: conn

  defp html_if_live_view(%{private: %{phoenix_live_view: _}} = conn), do: put_html_format(conn)
  defp html_if_live_view(conn), do: conn

  defp put_html_format(conn) do
    case Phoenix.Controller.get_format(conn) do
      "html" -> conn
      _ -> Phoenix.Controller.put_format(conn, "html")
    end
  end
end
