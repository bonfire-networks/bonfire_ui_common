defmodule Bonfire.UI.Common.NotificationLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop root_flash, :any, default: nil
  #  index of this component instance (2 is usually in PersistentLive)
  prop i, :integer, default: 1

  # These are `data` (not `prop`) so parent re-renders don't overwrite them
  # with default nil values. They are set via send_update from assign_flash.
  data notification, :any, default: nil
  data error, :any, default: nil
  data warning, :any, default: nil
  data info, :any, default: nil
  data error_sentry_event_id, :any, default: nil

  # Whether push works on this device, as this socket's own hook reported it. `nil` until it has, when the connect param stands in (see `Bonfire.UI.Common.Notifications.client_push_active/1`), and `nil` there too on a first visit, which counts as no push.
  data push_active, :boolean, default: nil

  # for PushNotifyLive
  data vapid_public_key, :string, default: nil
  data is_pwa, :boolean, default: false
  data subscriptions, :list, default: []
  data subscription_size, :integer, default: 0

  def mount(socket) do
    # debug("mounting")
    # need this if included in a non-Surface view/component which doesn't set Surface prop defaults
    {:ok,
     (maybe_apply(Bonfire.Notify.LiveHandler, :mount, [socket], fallback_return: nil) || socket)
     |> assign(
       root_flash: nil,
       notification: nil,
       error: nil,
       warning: nil,
       info: nil,
       error_sentry_event_id: nil
     )}
  end

  # def update(%{"notification" => _notification}, %{assigns: %{subscribed: true}} = socket) do
  #   {:ok,
  #    socket
  #    # FIXME: clearing here is a TEMP fix to avoid overlapping alerts
  #    |> special_clear_all()
  #   }
  # end

  def update(assigns, %{assigns: %{subscribed: _}} = socket) do
    {:ok,
     socket
     |> assign(without_duplicate_toast(assigns, socket))
     |> maybe_apply_root_flash()}
  end

  # A notification that arrives while push works on this device is already on screen, shown by the service worker, so a toast would be the same thing twice. Dropped here rather than never sent, because this socket receives it through whatever the page subscribes to (a notifications feed view subscribes to the very topic notifications are broadcast on), so the only place that can decide is the one that knows about push. Unknown counts as "no push": a toast somebody did not need costs less than a notification they never saw.
  defp without_duplicate_toast(%{notification: notification} = assigns, socket)
       when not is_nil(notification) do
    if push_active?(socket) do
      debug("push works on this device, so the service worker shows this rather than a toast")
      Map.drop(assigns, [:notification])
    else
      assigns
    end
  end

  defp without_duplicate_toast(assigns, _socket), do: assigns

  def update(assigns, socket) do
    # debug(assigns, "assigns")
    current_user = current_user(socket) || current_user(assigns)

    # heavy-load banner: `Bonfire.Common.Overload` re-broadcasts a notice each tick while elevated — handled by the parent LV via LiveHandlers → assign_flash back to this component, whose natural auto-fade is the all-clear. Same i==2 gate as below so the parent LV process subscribes only once.
    if assigns[:i] == 2, do: PubSub.subscribe("bonfire:overload", socket)

    # only where this device needs the in-page fallback, which the first connect knows from a cached param and the hook confirms a moment later (`push_state` below). Where push works the service worker shows the notification, so subscribing here would mean carrying a message to show a second popup nobody asked for
    subscribed? =
      if assigns[:i] == 2 and not is_nil(current_user) and fallback_needed?(socket, assigns) do
        subscribe_to_own_notifications(current_user, socket)
      else
        debug("not subscribing to the notification fallback")
        false
      end

    {:ok,
     socket
     |> assign(without_duplicate_toast(assigns, socket))
     |> assign(subscribed: subscribed?)
     |> maybe_apply_root_flash()}
  end

  # What this socket currently believes about push here: its hook's own report wins, and until that arrives the connect param the browser cached last time stands in. Absent from both means a first visit, which counts as no push, since a message nobody needed costs less than a notification nobody saw.
  defp push_active?(socket, assigns \\ %{}) do
    case e(assigns, :push_active, nil) do
      value when is_boolean(value) ->
        value

      _ ->
        case socket.assigns[:push_active] do
          value when is_boolean(value) -> value
          _ -> e(assigns(socket), :__context__, :client_push_active, nil) == true
        end
    end
  end

  defp fallback_needed?(socket, assigns), do: not push_active?(socket, assigns)

  defp subscribe_to_own_notifications(current_user, socket) do
    feed_id =
      maybe_apply(Bonfire.Social.Feeds, :my_feed_id, [:notifications, current_user],
        fallback_return: nil
      )

    if feed_id do
      debug(feed_id, "subscribed to the notification fallback")
      PubSub.subscribe(feed_id, socket)
      true
    else
      debug("no feed_id, not subscribing to the notification fallback")
      false
    end
  end

  @doc """
  What the browser knows about push on this device, so this socket can stop carrying what it does not need.

  Two halves make one answer: the browser says whether it holds a subscription, and the server says whether this person is still linked to it, which a shared browser makes a different question (somebody turning push off leaves the browser's subscription in place for everyone else). Push counts as working only if both agree, and anything else leaves the fallback on.
  """
  def handle_event("push_state", params, socket) do
    user = current_user(socket)

    push_active? =
      e(params, "active", false) == true and
        maybe_apply(
          Bonfire.Notify.WebPush,
          :subscribed_at?,
          [id(user), e(params, "endpoint", nil)],
          fallback_return: false
        ) == true

    {:noreply,
     socket
     |> assign(push_active: push_active?)
     |> update_fallback_subscription(push_active?, user)}
  end

  # A subscription can start or stop being needed while somebody is looking at the page: they turn push on from the settings panel, or clear site data, or another tab unsubscribes the browser. The hook announces each of those, so this follows rather than waiting for a reload.
  defp update_fallback_subscription(socket, true, _user) do
    if socket.assigns[:subscribed] do
      unsubscribe_from_own_notifications(socket)
      assign(socket, subscribed: false)
    else
      socket
    end
  end

  defp update_fallback_subscription(socket, false, user) do
    if socket.assigns[:subscribed] or is_nil(user) or socket.assigns[:i] != 2 do
      socket
    else
      assign(socket, subscribed: subscribe_to_own_notifications(user, socket))
    end
  end

  defp unsubscribe_from_own_notifications(socket) do
    feed_id =
      maybe_apply(
        Bonfire.Social.Feeds,
        :my_feed_id,
        [:notifications, current_user(socket)],
        fallback_return: nil
      )

    if feed_id do
      debug(feed_id, "push works here now, so the fallback subscription goes")
      PubSub.unsubscribe(feed_id)
    end
  end

  # def show(js \\ %JS{}, selector) do
  #   JS.show(js,
  #     to: selector,
  #     time: 300,
  #     display: "inline-block",
  #     transition:
  #       {"ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
  #        "opacity-100 translate-y-0 sm:scale-100"}
  #   )
  # end

  # def hide(js \\ %JS{}, selector) do
  #   JS.hide(js,
  #     to: selector,
  #     time: 300,
  #     transition:
  #       {"transition ease-in duration-300", "transform opacity-100 scale-100",
  #        "transform opacity-0 scale-95"}
  #   )
  # end

  def handle_event("clear-flash", %{"key" => type}, socket) do
    # This event is called from JavaScript when:
    # 1. User manually clicks close button
    # 2. Auto-fade timer completes
    # The JS hook will cancel its own timer before sending this event
    case maybe_to_atom!(type) do
      nil ->
        error(type, "invalid flash key")

      key ->
        {:noreply,
         socket
         |> special_clear_flash(key, type)}
    end
  end

  def handle_event("click_away", _, socket) do
    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, special_clear_all(socket)}
  end

  def special_clear_all(socket) do
    socket
    |> special_clear_flash(:info)
    |> special_clear_flash(:warning)
    |> special_clear_flash(:error)
    |> special_clear_flash(:notification)
  end

  def special_clear_flash(socket, key, alt_key \\ nil) do
    string_key = to_string(key)

    drop_keys =
      Enum.reject([key, alt_key, string_key, if(alt_key, do: to_string(alt_key))], &is_nil/1)

    socket
    |> clear_flash(key)
    |> assign(
      :root_flash,
      e(assigns(socket), :root_flash, %{})
      |> Map.drop(drop_keys)
    )
    |> assign(key, nil)
  end

  # Extract flash values from root_flash (which uses string keys from Phoenix put_flash)
  # into the data assigns, so they're accessible via @info / @error in the template
  defp maybe_apply_root_flash(socket) do
    case socket.assigns[:root_flash] do
      flash when is_map(flash) and flash != %{} ->
        socket
        |> maybe_set_from_flash(flash, "info", :info)
        |> maybe_set_from_flash(flash, "warning", :warning)
        |> maybe_set_from_flash(flash, "error", :error)

      _ ->
        socket
    end
  end

  defp maybe_set_from_flash(socket, flash, string_key, atom_key) do
    # Only set if the data assign is currently nil (don't overwrite send_update values)
    case {socket.assigns[atom_key], Map.get(flash, string_key)} do
      {nil, value} when not is_nil(value) -> assign(socket, atom_key, value)
      _ -> socket
    end
  end

  def error_template(assigns) do
    link =
      case maybe_last_sentry_event_id() do
        id when is_binary(id) ->
          org =
            Settings.get(:sentry_org, "bonfire-networks",
              name: l("Sentry Organization"),
              description: l("Sentry error reporting organization.")
            )

          "https://sentry.io/organizations/#{org}/issues/?query=#{id}"

        _ ->
          nil
      end

    # debug(assigns)
    error =
      e(assigns, :error, nil) ||
        e(
          e(assigns, :root_flash, nil) || e(assigns, :flash, %{}),
          :error,
          nil
        )

    # debug(error)

    Settings.get(
      [:ui, :error_post_template],
      "I encountered this issue while using Bonfire: \n\n%{error_message}\n\n@BonfireBuilders #bonfire_feedback \n\n%{error_link}",
      context: e(assigns, :context, nil),
      name: l("Error Report Template"),
      description: l("Template for reporting errors to the Bonfire team.")
    )
    |> String.replace("%{error_message}", error || "")
    |> String.replace("%{error_link}", link || "")

    # |> debug()
  end
end
