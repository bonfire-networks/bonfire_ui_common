defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # NOTE: you should put the "indicator" class on the parent element

  prop counter_class, :css_class, default: ""

  prop count, :integer, default: 0
  prop feed_id, :any, default: nil

  # defaults to current user
  prop for_user, :any, default: nil

  prop non_async, :boolean, default: false

  def update(%{count_increment: inc}, socket) do
    new_count = e(assigns(socket), :count, 0) + inc
    feed_id = e(assigns(socket), :feed_id, nil)

    if feed_id, do: persistent_put(socket, feed_id, new_count)

    {:ok, assign(socket, count: new_count)}
  end

  def update(%{count_loaded: true} = assigns, socket) do
    feed_id = e(assigns, :feed_id, nil) || e(assigns(socket), :feed_id, nil)
    count = e(assigns, :count, 0)

    if feed_id, do: persistent_put(socket, feed_id, count)

    {:ok, assign(socket, assigns)}
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
    for_user = e(assigns, :for_user, nil) || current_user(socket)

    case e(assigns, :id, nil) do
      component_name when not is_nil(component_name) and not is_nil(for_user) ->
        feed_id =
          e(assigns, :feed_id, nil) ||
            Bonfire.Common.Utils.maybe_apply(
              Bonfire.Social.Feeds,
              :my_feed_id,
              [component_name, for_user]
            )

        if e(assigns, :non_async, false) do
          unseen_count =
            Bonfire.Common.Utils.maybe_apply(
              Bonfire.Social.FeedActivities,
              :unseen_count,
              [feed_id, current_user: for_user]
            )

          persistent_put(socket, feed_id, unseen_count)

          {:ok,
           socket
           |> assign(count: unseen_count, count_loaded: true)}
        else
          # subscribe to count updates
          PubSub.subscribe("unseen_count:#{component_name}:#{feed_id}", socket)

          # Check PersistentLive's process dictionary — it survives navigation,
          # so this avoids re-querying on every component re-mount
          case persistent_get(socket, feed_id) do
            count when is_integer(count) ->
              {:ok, assign(socket, count: count, count_loaded: true)}

            _ ->
              pid = self()

              apply_task(:start, fn ->
                unseen_count =
                  Bonfire.Common.Utils.maybe_apply(
                    Bonfire.Social.FeedActivities,
                    :unseen_count,
                    [feed_id, current_user: for_user]
                  )

                # send_update triggers update(%{count_loaded: true}, ...) in the LV process,
                # which also stores the count in PersistentLive's process dict
                if socket_connected?(socket) != false,
                  do:
                    maybe_send_update(
                      __MODULE__,
                      component_name,
                      [count_loaded: true, count: unseen_count, feed_id: feed_id],
                      pid
                    )
              end)

              {:ok, socket}
          end
        end

      _ ->
        {:ok, socket}
    end
  end

  # Store a badge count in PersistentLive's process dict (survives navigation)
  defp persistent_put(socket, feed_id, count) do
    Bonfire.UI.Common.Presence.process_put(current_user_id(socket), {:badge_count, feed_id}, count)
  end

  # Read a badge count from PersistentLive's process dict
  defp persistent_get(socket, feed_id) do
    try do
      Bonfire.UI.Common.Presence.process_get(current_user_id(socket), {:badge_count, feed_id}, nil)
    catch
      :exit, _ -> nil
    end
  end
end
