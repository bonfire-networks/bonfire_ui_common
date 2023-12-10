defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop class, :css_class,
    default:
      "indicator-item !w-2 !h-2 !p-0 badge rounded-full bg-base-content/90 border-0 badge-sm"

  prop counter_class, :css_class, default: ""

  prop count, :integer, default: 0
  prop feed_id, :any, default: nil

  def update(%{count_increment: inc}, socket) do
    debug(inc, "receive count_increment")

    {:ok,
     assign(socket,
       count: e(socket.assigns, :count, 0) + inc
     )}
  end

  def update(%{count_loaded: true} = assigns, socket) do
    debug(assigns, "assign loaded count")

    {:ok,
     assign(
       socket,
       assigns
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
    debug("load Badge count")

    # debug(assigns, "assigns")

    socket = assign(socket, assigns)
    current_user = current_user(socket.assigns)

    case e(assigns, :id, nil) do
      feed_name when not is_nil(feed_name) and not is_nil(current_user) ->
        feed_id =
          e(assigns, :feed_id, nil) || Bonfire.Social.Feeds.my_feed_id(feed_name, current_user)

        # subscribe to count updates
        PubSub.subscribe("unseen_count:#{feed_name}:#{feed_id}", socket)

        pid = self()

        Task.start(fn ->
          debug(feed_name, "show badge for")

          unseen_count =
            Bonfire.Social.FeedActivities.unseen_count(feed_id,
              current_user: current_user
            )
            |> debug("unseen_count for #{feed_name}")

          if socket_connected?(socket) != false,
            do:
              maybe_send_update(
                __MODULE__,
                feed_name,
                [count_loaded: true, count: unseen_count],
                pid
              )
        end)

        {:ok, socket}

      _ ->
        error("No id or no user, so could not fetch count or pub-subscribe to counter")

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
