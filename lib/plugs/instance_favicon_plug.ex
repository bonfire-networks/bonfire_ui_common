defmodule Bonfire.UI.Common.InstanceFaviconPlug do
  @behaviour Plug

  alias Bonfire.Common.Config
  alias Bonfire.UI.Common.SEOImage
  require Config

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: method, request_path: "/favicon.ico"} = conn, _opts)
      when method in ["GET", "HEAD"] do
    instance_icon = Config.get([:ui, :theme, :instance_icon])

    with true <- SEOImage.custom_instance_icon?(instance_icon),
         icon_url when is_binary(icon_url) <- SEOImage.social_icon_url(instance_icon),
         false <- self_referential?(conn, icon_url) do
      redirect_to_icon(conn, icon_url)
    else
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  # Redirecting this path to itself loops until the browser gives up, which is a worse outcome
  # than serving the bundled icon. `custom_instance_icon?/1` already rejects the conventional
  # spellings, but an icon can still *resolve* here (e.g. a rewritten or hand-edited setting).
  defp self_referential?(conn, icon_url) do
    %URI{path: path, host: host} = URI.parse(icon_url)
    path == conn.request_path and host in [nil, conn.host, base_host()]
  end

  defp base_host do
    case Bonfire.Common.URIs.base_url() do
      base when is_binary(base) -> URI.parse(base).host
      _ -> nil
    end
  end

  # only reached with a binary URL that is not this request's own
  defp redirect_to_icon(conn, icon_url) do
    conn
    |> Plug.Conn.put_resp_header("location", icon_url)
    |> Plug.Conn.put_resp_header("cache-control", "public, max-age=3600")
    |> Plug.Conn.send_resp(302, "")
    |> Plug.Conn.halt()
  end
end
