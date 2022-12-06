defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop class, :css_class, default: ""
  prop count, :integer, default: 0

  def update(%{count_increment: inc}, socket) do
    debug(inc, "count_increment")

    {:ok,
     assign(socket,
       count: e(socket.assigns, :count, 0) + inc
     )}
  end

  def update(assigns, %{assigns: %{count_loaded: true}} = socket) do
    # debug(assigns, "count already loaded")
    {:ok,
     assign(
       socket,
       assigns
     )}
  end

  def update(assigns, socket) do
    debug("load count")

    # debug(assigns, "assigns")

    socket = assign(socket, assigns)
    current_user = current_user(socket)

    case e(assigns, :id, nil) do
      feed_name when not is_nil(feed_name) and not is_nil(current_user) ->
        debug(feed_name, "show badge for")
        feed_id = Bonfire.Social.Feeds.my_feed_id(feed_name, current_user)

        unseen_count =
          Bonfire.Social.FeedActivities.unseen_count(feed_id,
            current_user: current_user
          )
          |> debug("unseen_count for #{feed_name}")

        # subscribe to count updates
        PubSub.subscribe("unseen_count:#{feed_name}:#{feed_id}", socket)

        {:ok,
         assign(
           socket,
           count_loaded: true,
           count: unseen_count
         )}

      _ ->
        error("No id, so could not fetch count or pub-subscribe to counter")

        {:ok, socket}
    end
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
