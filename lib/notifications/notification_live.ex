defmodule Bonfire.UI.Common.NotificationLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop notification, :any, default: nil
  prop error, :any, default: nil
  prop info, :any, default: nil

  def update(assigns, %{assigns: %{subscribed: true}} = socket) do
    {:ok, socket
          |> assign(assigns)
    }
  end

  def update(assigns, socket) do
    feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, current_user(assigns))

    if feed_id do
      debug(feed_id, "subscribed to push notifications")
      pubsub_subscribe(feed_id, socket)
    else
      debug("no feed_id, not subscribing to push notifications")
    end

    {:ok, socket
          |> assign(assigns)
          |> assign(subscribed: true)
    }
  end

  def handle_event("clear-flash", %{"key"=> key}, socket) do
    key = maybe_to_atom(key)

    {:noreply, socket
      |> clear_flash(key)
      |> assign(key, nil)
    }
    |> debug
  end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
