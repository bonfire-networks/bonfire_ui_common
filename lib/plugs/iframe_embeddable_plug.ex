defmodule Bonfire.UI.Common.Plugs.IframeEmbeddablePlug do
  @moduledoc """
  Removes the default `x-frame-options: SAMEORIGIN` header set by
  `put_secure_browser_headers` and replaces it with a CSP `frame-ancestors`
  directive, allowing this page to be embedded in iframes from external origins.

  Configure allowed origins via the `IFRAME_ALLOWED_ORIGINS` env var (default: `'self'`).
  Set to `*` to allow any origin, or a space-separated list of origins.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed = System.get_env("IFRAME_ALLOWED_ORIGINS", "'self'")

    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header("content-security-policy", "frame-ancestors #{allowed}")
  end
end
