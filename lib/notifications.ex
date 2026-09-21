defmodule Bonfire.UI.Common.Notifications do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  # Kept as a no-op rather than deleted: the hook no longer asks for this, but each flavour repo carries a built copy of that JS, so a stale bundle can still push the event, and an unhandled event is an error in the LiveView.
  def handle_event("request", _attrs, socket) do
    {:noreply, socket}
  end

  @doc """
  A notification for whoever is here, either as fields to word or as words already.

  The live path sends fields (`Bonfire.Social.Activities.describe_parts/1`), since the process that published knows what happened but not what language each recipient reads, so the wording happens here, once per person who is there to see it. A caller with a sentence of its own, like an admin announcement, sends that instead and it is passed through.
  """
  def handle_info(%{} = attrs, socket) do
    case notification_fields(attrs) do
      %{} = fields ->
        assign_notification(fields, socket)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(attrs, socket) do
    # debug(attrs, "receive_notification")
    assign_notification(attrs, socket)
  end

  @doc """
  The fields a notification is shown from, whichever way it arrived.

  Everything that consumes a notification broadcast needs the same two steps, and there is more than one of them (a LiveView here, the SSE stream in `bonfire_notify`), so they happen once here rather than once each.
  """
  def notification_fields(%{verb: _} = parts) do
    case maybe_apply(Bonfire.Social.Activities, :localise_describe, [parts], fallback_return: nil) do
      %{} = described ->
        # `body` is what a description calls it, `message` is what a notification calls it: renamed here rather than by each sender, so one place knows both names
        described
        |> Map.put(:message, Map.get(described, :body))
        |> Map.delete(:body)

      _ ->
        error(parts, "could not put this notification into words")
        nil
    end
  end

  def notification_fields(%{} = already_worded), do: already_worded

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
    # NOTE: Server-side timer disabled in favor of client-side auto-fade for reliability
    # The client-side JavaScript hook now handles auto-clearing with smooth animations
    # Process.send_after(pid, :clear_flash, 5000)

    if socket_connected?(context) != false,
      do: maybe_send_update(Bonfire.UI.Common.NotificationLive, :notification, attrs, pid)
  end

  def receive_notification(attrs, socket \\ nil)

  def receive_notification(attrs, nil) do
    receive_flash(attrs)
  end

  def receive_notification(attrs, socket) do
    receive_flash(attrs, nil, assigns(socket)[:__context__])
    # NOTE: should this call assign_notification instead?
  end

  @doc """
  Whether the browser said push was working here, from the params it carries on connect.

  `true`, `false`, or `nil` for "it has not said yet", which is not the same as `false` and must stay tellable apart: the first is a device whose notifications arrive without a page open, the second is a device that needs the page to show them, and the third is a first visit, where showing a notification twice is a smaller harm than showing it never. Written by the notification hook into `bonfire:push:active` (see `assets/js/local_storage_params.js`).
  """
  def client_push_active(%{} = connect_params) do
    case ed(connect_params, "push", "active", nil) do
      value when is_boolean(value) -> value
      _ -> nil
    end
  end

  def client_push_active(_), do: nil

  @doc """
  Hands a notification to the component that shows it, and to the hook that may turn it into an OS notification.

  Both go to `Bonfire.UI.Common.NotificationLive` rather than to this LiveView's own assigns, because it owns both decisions: whether an in-page toast is this person's notification or a duplicate of one the service worker is already showing, and whether the browser can show anything at all. It is also the only place that knows, since push works per device and a socket learns that from its own hook.
  """
  def assign_notification(attrs, socket) do
    debug(attrs)

    receive_flash(%{notification: attrs}, self(), assigns(socket)[:__context__])

    {:noreply,
     socket
     # send to the hook of the component in PersistentLive, which shows an OS notification only where push is not doing it
     |> maybe_push_event("notify:notifications-2", attrs)}
  end

  # def process_state(pid) when is_pid(pid), do: :sys.get_state(pid)
end
