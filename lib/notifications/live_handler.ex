defmodule Bonfire.Notifications.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  def handle_event("request", _attrs, socket) do
    Bonfire.Notifications.receive_notification(%{tile: "Receive notifications?", message: "OK"}, socket)
  end

  def handle_info(attrs, socket) do
    Bonfire.Notifications.receive_notification(attrs, socket)
  end

end
