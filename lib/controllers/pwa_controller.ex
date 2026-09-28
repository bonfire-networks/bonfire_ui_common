defmodule Bonfire.UI.Common.PWAController do
  @moduledoc """
  The instance-specific parts of the PWA:

    - `manifest/2`: the bundled `pwa/manifest.json` with the instance's name, description and icon, so the installed app is named after the instance. Served under `/pwa/` so the base's relative icon paths still resolve.
    - `open/2`: target of the manifest's `protocol_handlers` (`web+ap://`, FEP-07d7), looked up through search so remote objects get fetched.
  """
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Common.Config
  alias Bonfire.UI.Common.SEOImage
  require Config

  @base_manifest_path Path.expand("../../assets/static/pwa/manifest.json", __DIR__)
  @external_resource @base_manifest_path
  @base_manifest @base_manifest_path |> File.read!() |> Jason.decode!()

  # Browsers skip manifest icons with a wrong size, and the only custom icon whose size we know
  # without fetching it is the square PNG `SEOImage` renders.
  @rendered_icon_prefix "/data/uploads/instance/seo/instance-icon-"
  @rendered_icon_size "512x512"

  @ap_schemes ["web+ap://", "web+activitypub://"]

  def manifest(conn, _params) do
    conn
    |> put_resp_content_type("application/manifest+json")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, Jason.encode!(manifest()))
  end

  def manifest do
    name = app_name()

    manifest =
      @base_manifest
      |> Map.merge(%{"name" => name, "short_name" => name})
      |> maybe_put_icon(custom_icon_url())

    case present(Config.get([:ui, :theme, :instance_description])) do
      nil -> manifest
      description -> Map.put(manifest, "description", description)
    end
  end

  @doc "What the installed app is called: the instance's name, or Bonfire's when it has none."
  def app_name,
    do: present(Config.get([:ui, :theme, :instance_name])) || @base_manifest["short_name"]

  def open(conn, %{"uri" => uri}) when is_binary(uri), do: redirect(conn, to: open_path(uri))
  def open(conn, _params), do: redirect(conn, to: "/")

  @doc "The local path to open for a link handed to the app by the OS (never off-site)."
  def open_path(uri) do
    uri = String.trim(uri)

    case Enum.find(@ap_schemes, &String.starts_with?(uri, &1)) do
      nil ->
        "/"

      scheme ->
        "/search?" <>
          URI.encode_query(%{"s" => "https://" <> String.replace_prefix(uri, scheme, "")})
    end
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil

  defp custom_icon_url do
    if SEOImage.custom_instance_icon?(Config.get([:ui, :theme, :instance_icon])),
      do: SEOImage.instance_icon_url()
  end

  # Replaces the bundled icons rather than adding to it: browsers pick by size and Android prefers
  # `maskable`, so a Bonfire icon left in the list would win on some devices.
  defp maybe_put_icon(manifest, icon_url) when is_binary(icon_url) do
    if String.starts_with?(to_string(URI.parse(icon_url).path), @rendered_icon_prefix) do
      Map.put(manifest, "icons", [
        %{
          "src" => icon_url,
          "sizes" => @rendered_icon_size,
          "type" => "image/png",
          "purpose" => "any"
        }
      ])
    else
      manifest
    end
  end

  defp maybe_put_icon(manifest, _), do: manifest
end
