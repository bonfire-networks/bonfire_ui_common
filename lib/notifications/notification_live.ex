defmodule Bonfire.UI.Common.NotificationLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.Me.Web.LivePlugs
  import Where

  prop notification, :any

  def mount(socket) do
    feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, socket)

    if feed_id do
        pubsub_subscribe(feed_id, socket)
    else
      debug("no feed_id, not subscribing to push notifications")
    end

    {:ok, socket}
  end

  # defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers
  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  # def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
