defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop class, :string, default: ""
  prop count, :integer, default: 0

  def update(%{count_increment: inc}, socket) do
    debug(inc, "count_increment")
    {:ok, socket
    |> assign(count: e(socket.assigns, :count, 0) + inc)}
  end

  def update(assigns, %{assigns: %{loaded: true}} = socket) do
    debug("count already loaded")
    {:ok, socket
    |> assign(assigns)}
  end

  def update(assigns, socket) do
    # debug(assigns, "assigns")

    socket = assign(socket, assigns)
    current_user = current_user(socket)

    case e(assigns, :id, nil) do
      feed_name when not is_nil(feed_name) and not is_nil(current_user) ->

        debug(feed_name, "show badge for")
        feed_id = Bonfire.Social.Feeds.my_feed_id(feed_name, current_user)

        unseen_count = Bonfire.Social.FeedActivities.unseen_count(feed_id, current_user: current_user)
        |> debug("unseen_count for #{feed_name}")

        # subscribe to count updates
        pubsub_subscribe("unseen_count:#{feed_name}:#{feed_id}", socket)

        {:ok, socket
          |> assign(
            loaded: true,
            count: unseen_count
          )
        }

      _ ->
        error("No id, so could not fetch count or pub-subscribe to counter")

        {:ok, socket}
    end
  end

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
end
