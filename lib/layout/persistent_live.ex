defmodule Bonfire.UI.Common.PersistentLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  # alias Bonfire.UI.Common.SmartInputLive
  alias Bonfire.UI.Common.Presence

  # @session_key :csrf_token
  @session_key :csrf_socket_token

  # on_mount {Bonfire.UI.Common.LivePlugs.Helpers, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, session, socket) do
    # TEMP: monitor memory used by the LV and children
    # Bonfire.Common.MemoryMonitor.start_link(__MODULE__)

    socket_connected? = socket_connected?(socket)

    connect_params =
      if(socket_connected?,
        do: Phoenix.LiveView.get_connect_params(socket) |> debug("connect_params"),
        else: %{}
      )

    session =
      input_to_atoms(session, also_discard_unknown_nested_keys: false)
      |> debug("data from session")

    # get from csrf_socket_token from Phoenix.LiveView.get_connect_params(socket)
    presence_token =
      (connect_params["_csrf_token"] || session[:context][@session_key])
      |> debug("presence_token")

    # subscribe
    # presence_token
    # |> PubSub.subscribe(socket)

    socket =
      socket
      #  |> debug("socket before assigns")
      |> assign(Map.drop(session, [:context]))
      |> assign_global((session[:context] || %{}) |> debug("persistent_context from session"))
      #  |> assign_new(
      #    :__context__,
      #    fn 
      #     previous_context ->
      #       # NOTE: cannot `assign_new/3` to copy the assign from parent LV for sticky child views, see https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#assign_new/3-when-connected
      #       Map.merge(session[:context] || %{}, previous_context || %{})
      #       |> Map.merge(%{
      #         socket_connected?: socket_connected?
      #       })
      #       |> debug("merged persistent_context")
      #    end
      #  )
      |> assign_defaults()
      |> Presence.present!(%{@session_key => presence_token})
      |> debug("socket prepared via session")

    if initial_parent_pid = session[:context][:initial_parent_pid] do
      debug(
        initial_parent_pid,
        "ask the parent LV to send its context to us, so we don't need to load from DB again"
      )

      send(initial_parent_pid, {:persistent_live_context_request, self()})
    else
      debug(
        "no initial_parent_pid or not connected, so skip asking parent LV to send its context to us"
      )
    end

    {:ok, socket, layout: false}
  end

  def update(%{to_circles: new_to_circles} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:to_circles, new_to_circles)
     |> assign_global(
       _already_live_selected_:
         Enum.uniq(e(assigns(socket), :__context, :_already_live_selected_, []) ++ [:to_circles])
     )}
  end

  # def handle_info(:clear_flash, socket) do
  #   {:noreply,  socket |> clear_flash()}
  # end

  defp assign_defaults(socket, fun \\ &assign_new/3) do
    socket
    |> fun.(:showing_within, fn -> nil end)
    # |> fun.(:context_id, fn -> nil end)
    # |> fun.(:reply_to_id, fn -> nil end)
    # |> fun.(:create_object_type, fn -> nil end)
    |> fun.(:to_boundaries, fn -> [] end)
    |> fun.(:to_circles, fn -> [] end)
    |> fun.(:smart_input_opts, fn -> %{} end)
    # |> fun.(:showing_within, fn -> nil end)
    |> fun.(:thread_mode, fn -> nil end)
    # |> fun.(:page, fn -> nil end)
    # |> fun.(:page_title, fn -> nil end)
    # |> fun.(:selected_tab, fn -> nil end)
    |> fun.(:activity_inception, fn -> nil end)
    # |> fun.(:title_open, fn -> nil end)
    |> fun.(:title_prompt, fn -> nil end)
    |> fun.(:preloaded_recipients, fn -> nil end)
    |> fun.(:locales, fn -> nil end)

    # |> fun.(:without_sidebar, fn -> nil end)
    # |> fun.(:without_secondary_widgets, fn -> nil end)
    #  |> fun.(:nav_items, fn -> nil end)
    # |> fun.(:sidebar_widgets, fn -> [] end)

    #  |> fun.(:page_header_aside, fn -> nil end)
    #  |> fun.(:custom_page_header, fn -> nil end)
    # |> fun.(:root_flash, fn -> nil end)
  end

  def maybe_send_assigns(assigns) do
    # send(self(), {:assign_persistent_self, persistent_assigns_filter(assigns)})
    maybe_send(assigns[:__context__], persistent_assigns_filter(assigns))
  end

  @doc """
  Set assigns for the persistent view
  """
  def set(context, assigns) do
    persistent_assigns_filter(assigns)
    |> maybe_send(context, ...)
  end

  def notify(context, attrs) do
    maybe_send(context, {:notification, %{notification: attrs, parent_pid: self()}})
  end

  defp persistent_assigns_filter(assigns) do
    assigns
    # |> debug("pre-filtering")
    |> Map.new()
    |> Map.take([
      :showing_within,
      # :reply_to_id,
      # :context_id,
      # :create_object_type,
      # :smart_input_component,
      :thread_mode,
      # :without_sidebar,
      # :without_secondary_widgets,
      # :to_boundaries,
      # :to_circles,
      :smart_input_opts,
      # :nav_items,
      # :custom_page_header,
      # :page_header_aside,
      # :root_flash,
      # :sidebar_widgets,
      # :page,
      # :page_title,
      # :selected_tab,
      :locales
    ])
    |> Map.put(
      :__context__,
      Enum.into(assigns[:__context__] || %{}, %{sticky: true, parent_pid: self()})
    )
    |> debug("persistent assigns filtered")
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
        send(self(), {:assign_persistent_self, assigns})
        true

      _ ->
        cond do
          child_pid = e(context, :child_pid, nil) ->
            debug(child_pid, "send to PersistentLive liveview process with child_pid")

            send(child_pid, {:assign_persistent_self, assigns})

            true

          presence_token = e(context, @session_key, nil) ->
            debug(presence_token, "send to PersistentLive liveview process with presence_token")

            user_id =
              (current_user_id(context) || current_user_id(assigns))
              |> debug("send to user_id")

            try_send_self(user_id, presence_token, assigns)

            # PubSub.broadcast(presence_token, {:assign_persistent_self, assigns})

            true

          true ->
            debug(
              context,
              "no `#{@session_key}` value available in context so can't send to sticky LV (if used)"
            )

            nil
        end
    end
  end

  defp try_send_self(user_id, session_id, assigns, attempt \\ 1) do
    debug(session_id, "find a presence for session")

    presences =
      (Presence.present_meta(user_id) || [])
      |> debug("present_meta - attempt ##{attempt}")
      |> Enum.filter(fn
        %{@session_key => presence_session_id} when presence_session_id == session_id -> true
        _ -> false
      end)

    # |> List.first()
    # |> e(:pid, nil)
    # |> debug("PID present for session")

    if presences != [] do
      # FIXME: this sends to every open Bonfire tab in the current browser
      Enum.map(
        presences,
        &(send(&1.pid, {:assign_persistent_self, assigns})
          |> debug("send to PersistentLive view"))
      )
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

  def handle_info({:assign_persistent_self, {:smart_input, assigns}}, socket) do
    assigns_map = assigns |> Map.new()

    # Extract and normalize smart_input_opts
    smart_input_opts = Map.get(assigns_map, :smart_input_opts, %{})

    smart_input_opts =
      if is_list(smart_input_opts), do: Map.new(smart_input_opts), else: smart_input_opts

    # Derive show_cw/show_sensitive for server-controlled visibility
    # and determine which JS push event to send for textarea value
    hidden_cw_sensitive = %{show_cw: false, show_sensitive: false}

    {smart_input_opts, push_action} =
      cond do
        assigns_map[:reset_smart_input] ->
          {Map.merge(smart_input_opts, hidden_cw_sensitive), :reset}

        is_binary(smart_input_opts[:cw]) and smart_input_opts[:cw] != "" ->
          {Map.merge(smart_input_opts, %{
             show_cw: true,
             show_sensitive: smart_input_opts[:inherit_sensitive] || false
           }), :set_cw}

        Map.has_key?(smart_input_opts, :cw) ->
          {Map.merge(smart_input_opts, hidden_cw_sensitive), :clear_cw}

        true ->
          {smart_input_opts, :none}
      end

    # Send updated assigns (with enriched smart_input_opts) to the container component
    assigns_map
    |> Map.put(:smart_input_opts, smart_input_opts)
    |> Map.put_new(:smart_input_component, nil)
    |> maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, ...)

    # Push JS events for textarea value manipulation only
    # (visibility and button state are now server-controlled via show_cw/show_sensitive)
    socket =
      case push_action do
        :reset ->
          socket
          |> Phoenix.LiveView.push_event("smart_input:reset", %{})
          |> Phoenix.LiveView.push_event("smart_input:reset_sensitive", %{})

        :set_cw ->
          socket
          |> Phoenix.LiveView.push_event("smart_input:set_cw", %{cw: smart_input_opts[:cw]})

        :clear_cw ->
          socket
          |> Phoenix.LiveView.push_event("smart_input:clear_cw", %{})

        :none ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:assign_persistent_self, {:media_player, assigns}}, socket) do
    debug("forward assigns from PersistentLive to the media_player_modal stateful component")

    maybe_send_update(Bonfire.UI.Common.ReusableModalLive, "media_player_modal", assigns)

    {:noreply, socket}
  end

  def handle_info({:assign_persistent_self, {:notification, assigns}}, socket) do
    debug("forward assigns from PersistentLive to the NotificationLive stateful component")

    maybe_send_update(Bonfire.UI.Common.NotificationLive, :notification, assigns)

    {:noreply, socket}
  end

  def handle_info({:assign_persistent_self, assigns}, socket) do
    # assigns =
    #   assigns
    #   #  |> debug("received assigns for PersistentLive")
    #   |> Map.new()
    #   # |> Map.put_new(:smart_input_component, nil)
    #   # |> assign_defaults(&Map.put_new_lazy/3)
    #   # |> Map.put(
    #   #   ...,
    #   #   :__context__,
    #   #   Map.merge(assigns(socket)[:__context__] || %{}, assigns[:__context__] || %{})
    #   #   |> Enums.merge_keeping_only_first_keys(...)
    #   # )
    #   |> debug("set prepared assigns received for PersistentLive")

    # parent_pid = assigns[:parent_pid] || e(assigns, :__context__, :parent_pid, nil)
    # if is_pid(parent_pid), do: send(parent_pid, :persistent_live_loading)

    context = Map.merge(assigns(socket)[:__context__] || %{}, assigns[:__context__] || %{})

    handle_info({:assign_persistent_self, {:smart_input, __context__: context}}, socket)

    {:noreply,
     socket
     |> assign(assigns)
     |> assign_global(context)
     #  |> assign_global(locales: e(assigns, :locales, nil) || e(context, :locales, nil))
     |> debug("set assigns received for PersistentLive")}
  end

  # Handle request from SmartInputContainerLive to push reset events
  # (needed when maybe_send fails and falls back to direct component update)
  def handle_info({:push_smart_input_reset_events}, socket) do
    {:noreply,
     socket
     |> Phoenix.LiveView.push_event("smart_input:reset", %{})
     |> Phoenix.LiveView.push_event("smart_input:reset_sensitive", %{})}
  end

  def handle_info({:process_put, key, value}, socket) do
    Process.put(key, value)
    {:noreply, socket}
  end

  def handle_call({:process_get, key, default}, _from, socket) do
    value =
      case Process.get(key, :__not_found__) do
        :__not_found__ -> Map.get(socket.assigns, key, default)
        found -> found
      end

    {:reply, value, socket}
  end
end
