defmodule Bonfire.UI.Common.Plugs.MaybeCSRFPlug do
  @moduledoc """
  Applies CSRF protection only for authenticated requests.

  Used in the `:browser_or_cacheable` pipeline to allow unauthenticated responses
  to be cached without CSRF tokens embedded in the HTML, while authenticated users
  still get proper CSRF tokens so the LiveView socket can connect.

  Auth state is detected via:
    * the session (`:current_user_id` key) — standard cookie-based auth; and
    * a valid `bonfire_embed_token` query param — cross-origin iframe embeds
      where third-party cookies are blocked. The token represents a completed
      login and will authenticate the LV at mount, so the HTML response needs
      a CSRF token for the LV socket to connect.

  Auth state is detected without loading the user into conn assigns, keeping
  token auth scoped to the LV/socket boundary.
  """

  import Plug.Conn

  def init(opts), do: opts

  @csrf_opts Plug.CSRFProtection.init([])

  def call(conn, _opts) do
    cond do
      get_session(conn, :current_user_id) ->
        Plug.CSRFProtection.call(conn, @csrf_opts)

      embed_token_authenticated?(conn) ->
        conn
        |> Plug.Conn.put_private(:bonfire_embed_token_authed, true)
        |> Plug.CSRFProtection.call(@csrf_opts)

      true ->
        conn
    end
  end

  defp embed_token_authenticated?(conn) do
    if Code.ensure_loaded?(Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken) do
      Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken.valid_token?(conn)
    else
      false
    end
  end
end
