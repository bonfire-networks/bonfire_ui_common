defmodule Bonfire.UI.Common.PersistentLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Common.SmartInputLive
  alias Bonfire.Common.Presence

  @session_key :csrf_token

  def mount(_params, session, socket) do
    session =
      input_to_atoms(session)
      |> debug("data from session")

    # subscribe
    # session[:context][@session_key]
    # |> debug("session_topic")
    # |> PubSub.subscribe(socket)

    {:ok,
     socket
     #  |> debug("socket before assigns")
     |> assign(Map.drop(session, [:context]))
     |> assign(:__context__, session[:context])
     |> assign_defaults()
     |> Presence.present!(%{@session_key => session[:context][@session_key]})
     |> debug("socket prepared via session"), layout: false}
  end

  defp assign_defaults(socket, fun \\ &assign_new/3) do
    socket
    |> fun.(:showing_within, fn -> nil end)
    |> fun.(:context_id, fn -> nil end)
    |> fun.(:reply_to_id, fn -> nil end)
    |> fun.(:create_object_type, fn -> nil end)
    |> fun.(:to_boundaries, fn -> [] end)
    |> fun.(:to_circles, fn -> [] end)
    |> fun.(:smart_input_opts, fn -> nil end)
    |> fun.(:showing_within, fn -> nil end)
    |> fun.(:show_select_recipients, fn -> false end)
    |> fun.(:thread_mode, fn -> nil end)
    |> fun.(:page, fn -> nil end)
    |> fun.(:page_title, fn -> nil end)
    |> fun.(:selected_tab, fn -> nil end)
    |> fun.(:activity_inception, fn -> nil end)
    |> fun.(:title_open, fn -> nil end)
    |> fun.(:title_prompt, fn -> nil end)
    |> fun.(:preloaded_recipients, fn -> nil end)
    |> fun.(:without_sidebar, fn -> nil end)
    |> fun.(:without_widgets, fn -> nil end)
    #  |> fun.(:nav_items, fn -> nil end)
    |> fun.(:sidebar_widgets, fn -> [] end)

    #  |> fun.(:page_header_aside, fn -> nil end)
    #  |> fun.(:custom_page_header, fn -> nil end)
    # |> fun.(:root_flash, fn -> nil end)
  end

  def maybe_send_assigns(assigns) do
    # send(self(), {:assign_persistent, persistent_assigns_filter(assigns)})
    maybe_send(assigns[:__context__], persistent_assigns_filter(assigns))
  end

  @doc """
  Set assigns for the persistent view
  """
  def set(context, assigns) do
    assigns = persistent_assigns_filter(assigns)
    maybe_send(context, assigns) || send_self(assigns)
  end

  defp persistent_assigns_filter(assigns) do
    assigns
    |> Map.new()
    |> Map.take([
      :showing_within,
      :reply_to_id,
      :context_id,
      :create_object_type,
      :smart_input_component,
      :thread_mode,
      :without_sidebar,
      :without_widgets,
      :to_boundaries,
      :to_circles,
      :smart_input_opts,
      # :nav_items,
      # :custom_page_header,
      # :page_header_aside,
      # :root_flash,
      :sidebar_widgets,
      :page,
      :page_title,
      :selected_tab
    ])
    |> Map.put(:__context__, Enum.into(assigns[:__context__] || %{}, %{sticky: true}))
  end

  def maybe_send(%{assigns: %{__context__: context}} = _socket, assigns),
    do: maybe_send(context, assigns)

  def maybe_send(%{__context__: context} = _socket_assigns, assigns),
    do: maybe_send(context, assigns)

  def maybe_send(context, assigns) do
    debug(assigns, "send persistent assigns")

    case e(context, :sticky, nil) do
      true ->
        debug("already in PersistentLive process")
        false

      _ ->
        debug("send to PersistentLive liveview process")

        if e(context, @session_key, nil) do
          session_id = e(context, @session_key, nil)

          user_id =
            (current_user_id(context) || current_user_id(assigns))
            |> debug("user_id")

          try_send_self(user_id, session_id, assigns)

          # PubSub.broadcast(session_id, {:assign, assigns})

          true
        else
          debug(
            context,
            "no csrf_token available in context so can't send to sticky LV (if used)"
          )

          :skip
        end
    end
  end

  defp try_send_self(user_id, session_id, assigns, attempt \\ 1) do
    pid =
      (Presence.present_meta(user_id) || [])
      |> debug("present_meta - attempt ##{attempt}")
      |> Enum.filter(fn
        %{@session_key => presence_session_id} when presence_session_id == session_id -> true
        _ -> false
      end)
      |> List.first()
      |> Utils.e(:pid, nil)
      |> debug("present for session")

    if pid do
      send(pid, {:assign, assigns})
      |> debug("send to PID")
    else
      if attempt < 10 do
        Process.send_after(
          self(),
          {__MODULE__, {:try_send_self, [user_id, session_id, assigns, attempt + 1]}},
          200
        )
        |> debug("send_after to self, to check again for the PID until found")
      else
        warn("give up sending assigns to PersistentLive since we can't find the PID in Presence")
      end
    end
  end

  def handle_info({:try_send_self, [user_id, session_id, assigns, attempt]}, socket) do
    try_send_self(user_id, session_id, assigns, attempt)

    {:noreply, socket}
  end

  def handle_info({:assign, {:smart_input, assigns}}, socket) do
    debug("forward assigns from PersistentLive to the SmartInputContainerLive stateful component")

    assigns
    |> Map.new()
    |> Map.put_new(:smart_input_component, nil)
    |> maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, ...)

    {:noreply, socket}
  end

  # def handle_info({:assign, {:notification, assigns}}, socket) do
  #   debug("forward assigns from PersistentLive to the NotificationLive stateful component")

  #   maybe_send_update(Bonfire.UI.Common.NotificationLive, :notification, assigns)

  #   {:noreply, socket}
  # end

  def handle_info({:assign, assigns}, socket) do
    {:noreply,
     assigns
     |> Map.new()
     |> Map.put(:smart_input_component, nil)
     |> assign_defaults(&Map.put_new_lazy/3)
     |> Map.put(
       ...,
       :__context__,
       Map.merge(socket.assigns[:__context__] || %{}, assigns[:__context__] || %{})
       |> merge_keeping_only_first_keys(...)
     )
     |> debug("set received assigns for PersistentLive")
     |> assign(socket, ...)}
  end

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

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
          __MODULE__
          # &do_handle_event/3
        )
end
