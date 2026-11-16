defmodule Bonfire.UI.Common.GenAvatar do
  use Bonfire.UI.Common.Web, :controller

  # TODO: use https://github.com/waseigo/identicon_svg as another option?

  # Output is deterministic per ID so a long CDN TTL is safe. Mark purgeable
  # in case the generation algorithm is ever updated.
  plug Bonfire.UI.Common.CacheControlPlug, purgeable: true

  @doc "The address of the generated avatar for an ID, signed so that only IDs the app itself links to are generated (and cached): anyone could otherwise fill the cache with made-up IDs. The signature is a segment of the path rather than a query string, as the static cache only keeps responses to requests without one."
  def path(id) when is_binary(id), do: "/gen_avatar/#{id}/#{sign(id)}"

  @doc "The signature `path/1` puts on an ID's address. Deterministic, so the same address stays cacheable across page renders."
  def sign(id) when is_binary(id) do
    :crypto.mac(:hmac, :sha256, secret_key_base(), "gen_avatar:" <> id)
    |> binary_part(0, 12)
    |> Base.url_encode64(padding: false)
  end

  def valid_signature?(id, sig) when is_binary(id) and is_binary(sig),
    do: Plug.Crypto.secure_compare(sign(id), sig)

  def valid_signature?(_, _), do: false

  defp secret_key_base, do: Bonfire.Common.Config.endpoint_module().config(:secret_key_base)

  # without an ID there is one fixed image, so nothing to fill the cache with
  def generate(conn, %{"id" => id} = params) when is_binary(id) do
    if valid_signature?(id, params["sig"]) do
      send_avatar(conn, id, params["sig"])
    else
      # the static cache writes only 200 responses, so this 404 stays out of it; a CDN may cache it like the image, since a wrongly signed address never becomes valid
      conn
      # |> put_private(:static_cacheable, false)
      # |> put_resp_header("cache-control", "no-store")
      |> send_resp(404, "")
    end
  end

  def generate(conn, _params), do: send_avatar(conn, "random", nil)

  # tagged by the address, which keeps a purge of an ID's tag (a prefix of it) reaching the file the static cache wrote
  defp send_avatar(conn, id, sig) do
    conn
    |> put_resp_content_type("image/svg+xml")
    |> put_resp_header("content-disposition", "filename=avatar.svg")
    |> Bonfire.UI.Common.CacheControlPlug.tag_response([
      Enum.join(["gen_avatar", id, sig], "/") |> String.trim_trailing("/")
    ])
    |> send_resp(200, Bonfire.UI.Common.AnimalAvatar.svg(id))
  end
end
