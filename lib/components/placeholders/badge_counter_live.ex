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
    # debug(assigns, "assigns")

    case e(assigns, :id, nil) do
      id when is_binary(id) ->

        # TODO: fetch
        unseen_count = Bonfire.Social.FeedActivities.unseen_count(id)
        |> debug("unseen_count for #{id}")

        # subscribe to count updates
        pubsub_subscribe("unseen_count:#{id}", socket)

        {:ok, socket
          |> assign(assigns)
          |> assign(count: unseen_count)
        }

      _ ->
        error("No id, so could not fetch count or pub-subscribe to counter")

        {:ok, socket
          |> assign(assigns)
        }
    end
  end

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
end
