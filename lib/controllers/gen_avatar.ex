defmodule Bonfire.UI.Common.GenAvatar do
  use Bonfire.UI.Common.Web, :controller

  # TODO: use https://github.com/waseigo/identicon_svg as another option?

  # Output is deterministic per ID so a long CDN TTL is safe. Mark purgeable
  # in case the generation algorithm is ever updated.
  plug Bonfire.UI.Common.CacheControlPlug, purgeable: true

  def generate(conn, params) do
    id = params["id"] || "random"

    conn
    |> put_resp_content_type("image/svg+xml")
    |> put_resp_header("content-disposition", "filename=avatar.svg")
    |> Bonfire.UI.Common.CacheControlPlug.tag_response(["gen_avatar/#{id}"])
    |> send_resp(200, Bonfire.UI.Common.AnimalAvatar.svg(id))
  end
end
