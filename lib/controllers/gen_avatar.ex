defmodule Bonfire.UI.Common.GenAvatar do
  use Bonfire.UI.Common.Web, :controller

  # TODO: use https://github.com/waseigo/identicon_svg as another option?

  def generate(conn, params) do
    conn
    |> put_resp_content_type("image/svg+xml")
    |> put_resp_header("content-disposition", "attachment; filename=avatar.svg")
    |> send_resp(200, Bonfire.UI.Common.AnimalAvatar.svg(params["id"] || "random"))
  end
end
