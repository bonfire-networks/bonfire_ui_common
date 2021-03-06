defmodule Bonfire.UI.Common.Notifications do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def handle_event("request", _attrs, socket) do
    receive_notification(%{title: l("Notifications enabled"), message: l("You will now receive notifications of messages, mentions, and other relevant activities."), icon: Config.get([:ui, :theme, :instance_icon], nil)}, socket)
  end

  def handle_info(attrs, socket) do
    # debug(attrs, "receive_notification")
    receive_notification(attrs, socket)
  end

  def notify_feeds(feed_ids, title, message, icon \\ nil) do
    %{title: title, message: Text.text_only(message), icon: icon || Config.get([:ui, :theme, :instance_icon], nil)}
    |> debug("to: #{inspect feed_ids}")
    |> pubsub_broadcast(feed_ids, {Bonfire.UI.Common.Notifications, ...}) # send to feed users' handle_info in this same module
  end

  def notify_me(title, message, icon, socket \\ nil) do
    receive_notification(
      %{title: title, message: Text.text_only(message), icon: icon},
      socket
    )
  end

  def receive_flash(attrs) do
    Map.merge(%{id: "notification"}, attrs)
    |> debug()
    |> send_update(Bonfire.UI.Common.NotificationLive, ...)
  end

  def receive_notification(attrs, socket \\ nil)

  def receive_notification(attrs, nil) do
    receive_flash(attrs)
  end

  def receive_notification(attrs, socket) do
    debug(attrs)
    {:noreply,
      socket
      |> assign(notification: attrs)
      |> push_event("notify", attrs)
    }
  end

  # def process_state(pid) when is_pid(pid), do: :sys.get_state(pid)

end
