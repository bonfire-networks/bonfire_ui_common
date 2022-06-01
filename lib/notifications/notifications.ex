defmodule Bonfire.Notifications do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def notify_feeds(feed_ids, title, message) do
    %{title: title, message: text_only(message)}
    |> debug()
    |> pubsub_broadcast(feed_ids, {Bonfire.Notifications, ...})
  end

  def notify_me(title, message, socket \\ nil) do
    receive_notification(
      %{title: title, message: text_only(message)},
    socket)
  end

  def receive_notification(attrs, socket \\ nil)

  def receive_notification(attrs, nil) do
    Map.merge(%{id: "notification"}, attrs)
    |> debug()
    |> send_update(Bonfire.UI.Common.NotificationLive, ...)
  end

  def receive_notification(attrs, socket) do
    {:noreply,
      socket
      |> assign(notification: attrs)
      |> push_event("notify", attrs)
    }
  end

  # def process_state(pid) when is_pid(pid), do: :sys.get_state(pid)


end
