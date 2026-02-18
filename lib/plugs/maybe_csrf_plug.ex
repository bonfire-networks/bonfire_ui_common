defmodule Bonfire.UI.Common.Plugs.MaybeCSRFPlug do
  @moduledoc """
  Applies CSRF protection only for authenticated requests.

  Used in the `:browser_or_cacheable` pipeline to allow unauthenticated responses
  to be cached without CSRF tokens embedded in the HTML, while authenticated users
  still get proper CSRF tokens so the LiveView socket can connect.

  Auth state is detected via the session (`:current_user_id` key) rather than
  assigns, because current_user is not loaded into assigns during the pipeline.
  """

  import Plug.Conn

  def init(opts), do: opts

  @csrf_opts Plug.CSRFProtection.init([])

  def call(conn, _opts) do
    if get_session(conn, :current_user_id) do
      Plug.CSRFProtection.call(conn, @csrf_opts)
    else
      conn
    end
  end
end
