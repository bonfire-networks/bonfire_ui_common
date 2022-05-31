defmodule Bonfire.UI.Common.BadgeCounterLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop class, :string, default: ""
  prop count, :integer, default: 0

  def update(%{count_increment: inc}, socket) do
    debug(inc, "count_increment")
    {:ok, socket
    |> assign(count: e(socket.assigns, :count, 0) + inc)}
  end

  def update(assigns, socket) do
    debug(assigns, "assigns")

    case e(assigns, :id, nil) do
      id when is_binary(id) ->
        pubsub_subscribe("unread_count:#{id}", socket)
      _ ->
        error("Could not pub-subscribe to counter")
    end

    {:ok, socket
    |> assign(assigns)}
  end

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
end
