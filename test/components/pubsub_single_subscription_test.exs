defmodule Bonfire.UI.Common.PubsubSingleSubscriptionTest do
  @moduledoc "A LiveView process that mounts a component again, or updates one before its count has loaded, must not subscribe to the same topic twice: each broadcast would reach it twice."
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.PubSub
  alias Bonfire.UI.Common.{BadgeCounterLive, NotificationLive}

  # a component's socket, as its page's process holds it once connected
  defp connected_socket(assigns),
    do: %Phoenix.LiveView.Socket{
      transport_pid: self(),
      assigns: Map.merge(%{__changed__: %{}}, assigns)
    }

  defp assert_received_once(topic) do
    :ok = PubSub.broadcast(topic, {:probe, topic})
    assert_receive {:probe, ^topic}
    refute_receive {:probe, ^topic}, 100
  end

  setup do
    %{me: fake_user!(fake_account!())}
  end

  test "two notification components in one process hear the heavy-load notice once", %{me: me} do
    for _ <- 1..2 do
      {:ok, socket} =
        NotificationLive.mount(connected_socket(%{__context__: %{current_user: me}}))

      {:ok, _} =
        NotificationLive.update(%{id: "notification_#{Enum.random(1..9999)}", i: 2}, socket)
    end

    assert_received_once("bonfire:overload")
  end

  test "two notification components in one process hear my notifications once", %{me: me} do
    for _ <- 1..2 do
      {:ok, socket} =
        NotificationLive.mount(connected_socket(%{__context__: %{current_user: me}}))

      {:ok, socket} =
        NotificationLive.update(%{id: "notification_#{Enum.random(1..9999)}", i: 2}, socket)

      assert socket.assigns.subscribed
    end

    assert_received_once(Bonfire.Social.Feeds.my_feed_id(:notifications, me))
  end

  test "a badge counter updated again before its count has loaded hears its feed once", %{me: me} do
    feed_id = Needle.UID.generate()
    assigns = %{id: "badge", feed_id: feed_id, for_user: me}
    socket = connected_socket(%{__context__: %{current_user: me}})

    {:ok, socket} = BadgeCounterLive.update(assigns, socket)
    refute socket.assigns[:count_loaded]
    {:ok, _socket} = BadgeCounterLive.update(assigns, socket)

    assert_received_once("unseen_count:#{feed_id}")
  end
end
