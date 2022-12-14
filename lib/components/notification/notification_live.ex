defmodule Bonfire.UI.Common.NotificationLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop root_flash, :any, default: nil
  prop notification, :any, default: nil
  prop error, :any, default: nil
  prop info, :any, default: nil
  prop error_sentry_event_id, :any, default: nil

  def mount(socket) do
    # debug("mounting")
    # need this if included in a non-Surface view/component which doesn't set Surface prop defaults
    {:ok,
     assign(
       socket,
       root_flash: nil,
       notification: nil,
       error: nil,
       info: nil,
       error_sentry_event_id: nil
     )}
  end

  def update(assigns, %{assigns: %{subscribed: true}} = socket) do
    {:ok,
     assign(
       socket,
       assigns
     )}
  end

  def update(assigns, socket) do
    debug(assigns, "assigns")
    current_user = current_user(socket) || current_user(assigns)

    if current_user do
      feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, current_user)

      if feed_id do
        debug(feed_id, "subscribed to push notifications")
        PubSub.subscribe(feed_id, socket)
      else
        debug("no feed_id, not subscribing to push notifications")
      end
    else
      debug("no current_user, not subscribing to push notifications")
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(subscribed: true)}
  end

 
  def do_handle_event("clear-flash", %{"key" => type}, socket) do
    key = maybe_to_atom(type)

    {:noreply,
     socket
     |> clear_flash(type)
     |> assign(
       :root_flash,
       e(socket.assigns, :root_flash, %{})
       |> Map.drop([type, key])
     )
     |> assign(type, nil)
     |> assign(key, nil)}

    # |> debug
  end

  def do_handle_event("click_away", _, socket) do
    {:noreply, socket}
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__,
          &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def error_template(assigns) do
    link =
      case maybe_last_sentry_event_id() do
        id when is_binary(id) ->
          org = Settings.get(:sentry_org, "bonfire-networks")
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
      e(assigns, :context, nil)
    )
    |> String.replace("%{error_message}", error || "")
    |> String.replace("%{error_link}", link || "")

    # |> debug()
  end
end
