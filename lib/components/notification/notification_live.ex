defmodule Bonfire.UI.Common.NotificationLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop root_flash, :any, default: nil
  #  index of this component instance (2 is usually in PersistentLive)
  prop i, :integer, default: 1

  # These are `data` (not `prop`) so parent re-renders don't overwrite them
  # with default nil values. They are set via send_update from assign_flash.
  data notification, :any, default: nil
  data error, :any, default: nil
  data info, :any, default: nil
  data error_sentry_event_id, :any, default: nil

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
     |> assign(assigns)
     |> maybe_apply_root_flash()}
  end

  def update(assigns, socket) do
    # debug(assigns, "assigns")
    current_user = current_user(socket) || current_user(assigns)

    subscribed? =
      if assigns[:i] == 2 and current_user do
        feed_id =
          Bonfire.Common.Utils.maybe_apply(
            Bonfire.Social.Feeds,
            :my_feed_id,
            [:notifications, current_user]
          )

        if feed_id do
          debug(feed_id, "subscribed to push notifications")
          PubSub.subscribe(feed_id, socket)
          true
        else
          debug("no feed_id, not subscribing to push notifications")
          false
        end
      else
        debug("no current_user, not subscribing to push notifications")
        false
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(subscribed: subscribed?)
     |> maybe_apply_root_flash()}
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
