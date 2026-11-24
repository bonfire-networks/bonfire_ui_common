defmodule Bonfire.UI.Common.EmbedWidgetController do
  @moduledoc """
  Serves `/embed/widget/:id`: a widget declared embeddable, alone in the iframe layout, as guests see it (see `Bonfire.UI.Common.EmbedWidgetLive`). Any other id is a 404.

  Unless `CACHE_WIDGET_EMBEDS` is `false`, guests' copies are kept by the static cache and a proxy or CDN, one per query string, tagged so `Bonfire.UI.Common.Widgets.bust_embed/1` purges them together.
  """
  use Bonfire.UI.Common.Web, :controller

  plug :maybe_cache

  def show(conn, %{"id" => id} = params) do
    if Bonfire.UI.Common.Widgets.embeddable(id) do
      live_render(conn, Bonfire.UI.Common.EmbedWidgetLive,
        layout: {Bonfire.UI.Common.LayoutView, :iframe},
        # conn assigns don't reach a controller-rendered LiveView's mount, so `"params"` (which becomes its `current_params`) carries the id and options
        session: %{"params" => params}
      )
    else
      send_resp(conn, 404, "")
    end
  end

  defp maybe_cache(conn, _opts) do
    if Bonfire.Common.Config.get([__MODULE__, :cache], true) do
      conn
      |> Bonfire.UI.Common.CacheControlPlug.call(purgeable: true, cache_query_string: true)
      |> Bonfire.UI.Common.CacheControlPlug.tag_response([
        Bonfire.UI.Common.Widgets.embed_tag(conn.params["id"])
      ])
    else
      conn
    end
  end
end
