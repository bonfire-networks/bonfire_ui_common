defmodule Bonfire.UI.Common.Notifications do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  def handle_event("request", _attrs, socket) do
    receive_notification(
      %{
        title: l("Notifications enabled"),
        message:
          l(
            "You will now receive notifications of messages, mentions, and other relevant activities."
          ),
        icon: Config.get([:ui, :theme, :instance_icon], nil)
      },
      socket
    )

    {:noreply, socket}
  end

  def handle_info(attrs, socket) do
    # debug(attrs, "receive_notification")
    assign_notification(attrs, socket)
  end

  def notify_broadcast(to_ids, %{} = data) do
    data
    |> debug("to: #{inspect(to_ids)}")
    # send to feed users' handle_info in this same module
    |> PubSub.broadcast(to_ids, {Bonfire.UI.Common.Notifications, ...})
  end

  def notify_broadcast(to_ids, title, message, url \\ nil, icon \\ nil) do
    notify_broadcast(to_ids, %{
      title: title,
      message: Text.text_only(message),
      url: url,
      icon: icon || Config.get([:ui, :theme, :instance_icon], nil)
    })
  end

  def notify_me(title, message, icon, socket \\ nil) do
    receive_notification(
      %{title: title, message: Text.text_only(message), icon: icon},
      socket
    )
  end

  def receive_flash(attrs, pid \\ self(), context \\ nil) do
    # Bonfire.UI.Common.PersistentLive.notify(context, attrs) ||
    Process.send_after(pid, :clear_flash, 5000)

    if socket_connected?(context) != false,
      do: maybe_send_update(Bonfire.UI.Common.NotificationLive, :notification, attrs, pid)
  end

  def receive_notification(attrs, socket \\ nil)

  def receive_notification(attrs, nil) do
    receive_flash(attrs)
  end

  def receive_notification(attrs, socket) do
    receive_flash(attrs, nil, socket.assigns[:__context__])
    # NOTE: should this call assign_notification instead?
  end

  def assign_notification(attrs, socket) do
    debug(attrs)

    {:noreply,
     socket
     |> assign(notification: attrs)
     |> maybe_push_event("notify", attrs)}
  end

  # def process_state(pid) when is_pid(pid), do: :sys.get_state(pid)
end
