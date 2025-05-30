defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop counter_class, :css_class, default: ""

  prop count, :integer, default: 0
  prop feed_id, :any, default: nil

  def update(%{count_increment: inc}, socket) do
    {:ok,
     assign(socket,
       count: e(assigns(socket), :count, 0) + inc
     )}
  end

  def update(%{count_loaded: true} = assigns, socket) do
    {:ok,
     assign(
       socket,
       assigns
     )}
  end

  def update(assigns, %{assigns: %{count_loaded: true} = current_assigns} = socket) do
    current_count = e(current_assigns, :count, 0)

    # Preserve the loaded count when count_loaded: true to prevent parent updates from resetting it
    preserved_assigns =
      assigns
      |> Map.put(:count, current_count)
      |> Map.put(:count_loaded, true)

    {:ok, assign(socket, preserved_assigns)}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    current_user = current_user(socket)

    case e(assigns, :id, nil) do
      feed_name when not is_nil(feed_name) and not is_nil(current_user) ->
        feed_id =
          e(assigns, :feed_id, nil) ||
            Bonfire.Common.Utils.maybe_apply(
              Bonfire.Social.Feeds,
              :my_feed_id,
              [feed_name, current_user]
            )

        # subscribe to count updates
        PubSub.subscribe("unseen_count:#{feed_name}:#{feed_id}", socket)

        pid = self()

        Task.start(fn ->
          unseen_count =
            Bonfire.Common.Utils.maybe_apply(
              Bonfire.Social.FeedActivities,
              :unseen_count,
              [feed_id, current_user: current_user]
            )

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
        {:ok, socket}
    end
  end
end
