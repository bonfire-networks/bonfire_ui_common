defmodule Bonfire.UI.Common.MaybeStaticGeneratorPlug do
  use Plug.Builder
  import Untangle

  plug(:maybe_make_request_path_static)

  plug(Plug.Static,
    at: "/",
    from: {:bonfire, "priv/static/#{Bonfire.UI.Common.StaticGenerator.base_path()}"}
  )

  # do not serve cache when logged in
  def maybe_make_request_path_static(%{assigns: %{current_account: %{}}} = conn, _),
    do: conn

  def maybe_make_request_path_static(%{assigns: %{current_user: %{}}} = conn, _), do: conn

  def maybe_make_request_path_static(%{private: %{cache: cache}, assigns: %{}} = conn, _)
      when cache not in [nil, false] do
    debug(cache, "cache")
    Bonfire.UI.Common.StaticGeneratorPlug.make_request_path_static(conn)
  end

  def maybe_make_request_path_static(conn, _) do
    debug("do not cache")
    conn
  end
end
