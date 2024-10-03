defmodule Bonfire.UI.Common.MaybeStaticGeneratorPlug do
  use Plug.Builder
  import Untangle

  plug(:maybe_make_request_path_static)

  plug(:maybe_serve_static)
  # plug(Plug.Static,
  #   at: "/",
  #   from: {:bonfire, "priv/static/#{Bonfire.UI.Common.StaticGenerator.base_path()}"}
  # )

  def maybe_serve_static(conn, opts) do
    request_path = conn.request_path || "/"
    #  workaround for URLs like /@user@localhost:4000
    if not String.contains?(request_path, ":") do
      Plug.Static.call(conn,
        at: "/",
        from: {:bonfire, "priv/static/#{Bonfire.UI.Common.StaticGenerator.base_path()}"}
      )
    else
      conn
    end
  end

  # do not serve cache when logged in
  def maybe_make_request_path_static(%{assigns: %{current_account: %{}}} = conn, _),
    do: conn

  def maybe_make_request_path_static(%{assigns: %{current_user: %{}}} = conn, _), do: conn

  def maybe_make_request_path_static(%{private: %{cache: cache}, assigns: %{}} = conn, _)
      when cache not in [nil, false] do
    # because current_user is probably not yet in assigns
    if !get_session(conn, :current_user_id) do
      info(cache, "use cache for this route?")
      Bonfire.UI.Common.StaticGeneratorPlug.make_request_path_static(conn)
    else
      debug("do not use cache when signed in")
      conn
    end
  end

  def maybe_make_request_path_static(conn, _) do
    debug("do not use cache")
    conn
  end
end
