defmodule Bonfire.UI.Common.Plugs.IframeEmbeddablePlug do
  @moduledoc """
  Removes the default `x-frame-options: SAMEORIGIN` header set by
  `put_secure_browser_headers` and replaces it with a CSP `frame-ancestors`
  directive, allowing this page to be embedded in iframes from external origins.

  Configure allowed origins via the `IFRAME_ALLOWED_ORIGINS` env var (default: `'self'`). Set to `*` to allow any origin, or a space-separated list of origins.

  This is a CSP source list, so it is deliberately more permissive than the same env var's other consumer, `Bonfire.UI.Common.EmbedOrigins.allowed?/1` — letting a page *frame* us is not the same as trusting it with a bearer token.
  """

  import Plug.Conn

  alias Bonfire.UI.Common.EmbedOrigins

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header("content-security-policy", "frame-ancestors #{EmbedOrigins.frame_ancestors()}")
  end
end
