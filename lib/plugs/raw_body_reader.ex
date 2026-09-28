defmodule Bonfire.UI.Common.RawBodyReader do
  @moduledoc """
  Default `Plug.Parsers` body reader for every flavour. 

  Stashes the raw JSON payload in `conn.private[:bonfire_raw_body]` for signed-webhook verification (e.g. Ghost's `Bonfire.Ghost.Web.Plugs.VerifyGhostSignature`).

  Also delegates to `ActivityPub.Web.Plugs.DigestPlug.read_body/2` so ActivityPub HTTP-signature digests keep working.

  The stash is scoped to JSON requests only, so multipart uploads and urlencoded form bodies aren't held in memory unnecessarily.
  """

  alias Plug.Conn

  @raw_body_key :bonfire_raw_body

  def read_body(conn, opts) do
    with {:ok, body, conn} <- ActivityPub.Web.Plugs.DigestPlug.read_body(conn, opts) do
      {:ok, body, maybe_stash(conn, body)}
    end
  end

  defp maybe_stash(conn, body) do
    if conn |> Conn.get_req_header("content-type") |> Enum.any?(&String.contains?(&1, "json")) do
      Conn.put_private(conn, @raw_body_key, body)
    else
      conn
    end
  end
end
