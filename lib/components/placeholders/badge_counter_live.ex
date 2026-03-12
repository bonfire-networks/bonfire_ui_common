defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # NOTE: you should put the "indicator" class on the parent element

  prop counter_class, :css_class, default: ""

  prop count, :integer, default: 0
  prop feed_id, :any, required: true

  # defaults to current user
  prop for_user, :any, default: nil

  prop non_async, :boolean, default: false

  # When true, the component lives in PersistentLive and never re-mounts,
  # so we skip process dict caching and defensive re-mount logic

  def update(%{count_increment: inc} = assigns, socket) do
    new_count = e(assigns(socket), :count, 0) + inc
    feed_id = e(assigns, :feed_id, nil) || e(assigns(socket), :feed_id, nil)

    persistent? =
      e(assigns, :__context__, :sticky, nil) || e(assigns(socket), :__context__, :sticky, nil)

    if feed_id and !persistent?,
      do: persistent_put(socket, feed_id, new_count)

    {:ok, assign(socket, count: new_count)}
  end

  def update(%{count_loaded: true} = assigns, socket) do
    feed_id = e(assigns, :feed_id, nil) || e(assigns(socket), :feed_id, nil)
    count = e(assigns, :count, 0)

    persistent? =
      e(assigns, :__context__, :sticky, nil) || e(assigns(socket), :__context__, :sticky, nil)

    if feed_id && !persistent?,
      do: persistent_put(socket, feed_id, count)

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

    persistent? =
      e(assigns, :__context__, :sticky, nil) || e(assigns(socket), :__context__, :sticky, nil)

    component_name = e(assigns, :id, nil)

    if feed_id = e(assigns, :feed_id, nil) || e(assigns(socket), :feed_id, nil) do
      if e(assigns, :non_async, false) do
        #  just load the count but don't subscribe to pubsub

        load_count(socket, feed_id, for_user)
      else
        # subscribe to count updates
        PubSub.subscribe("unseen_count:#{feed_id}", socket)

        # For persistent badges (in PersistentLive), skip process dict cache
        # since we ARE the persistent process and never re-mount
        cached_count = if !persistent?, do: persistent_get(socket, feed_id)

        if is_integer(cached_count) do
          {:ok, assign(socket, count: cached_count, count_loaded: true)}
        else
          maybe_async_load_count(socket, component_name, feed_id, for_user, persistent?)
        end
      end
    else
      {:ok, socket}
    end
  end

  defp load_count(socket, feed_id, for_user) do
    unseen_count =
      Bonfire.Common.Utils.maybe_apply(
        Bonfire.Social.FeedActivities,
        :unseen_count,
        [feed_id, current_user: for_user]
      )

    {:ok,
     socket
     |> assign(count: unseen_count, count_loaded: true)}
  end

  defp maybe_async_load_count(socket, component_name, feed_id, for_user, persistent?) do
    if socket_connected?(socket) do
      pid = self()

      apply_task(:start, fn ->
        unseen_count =
          Bonfire.Common.Utils.maybe_apply(
            Bonfire.Social.FeedActivities,
            :unseen_count,
            [feed_id, current_user: for_user]
          )

        maybe_send_update(
          __MODULE__,
          component_name,
          [count_loaded: true, count: unseen_count, feed_id: feed_id, persistent: persistent?],
          pid
        )
      end)

      {:ok, socket}
    else
      load_count(socket, feed_id, for_user)
    end
  end

  # Store a badge count in PersistentLive's process dict (survives navigation)
  defp persistent_put(socket, feed_id, count) do
    Bonfire.UI.Common.Presence.process_put(
      current_user_id(socket),
      {:badge_count, feed_id},
      count
    )
  end

  # Read a badge count from PersistentLive's process dict
  defp persistent_get(socket, feed_id) do
    try do
      Bonfire.UI.Common.Presence.process_get(
        current_user_id(socket),
        {:badge_count, feed_id},
        nil
      )
    catch
      :exit, _ -> nil
    end
  end
end
