defmodule Bonfire.UI.Common.PersistentLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  use Arrows
  # alias Bonfire.UI.Common.SmartInputLive
  alias Bonfire.UI.Common.Presence

  # @session_key :csrf_token
  @session_key :csrf_socket_token

  # on_mount {Bonfire.UI.Common.LivePlugs.Helpers, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def sticky_badges do
    # TODO: get from config or behaviour registry?
    [:notifications, :inbox]
  end

  def feed_key(badge_id) do
    :"#{badge_id}_id"
  end

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

    # Seed reading positions into our process dict from connect_params
    # (this is PersistentLive, so the dict persists across live navigations;
    # the JS hook pushes updates via pushEvent as the user scrolls)
    Enum.each(connect_params["reading_pos"] || %{}, fn {feed_name, cursor} ->
      Process.put({:reading_pos, feed_name}, cursor)
    end)

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

  # defp do_update(%{to_circles: new_to_circles} = assigns, socket) do
  #   {:ok,
  #    socket
  #    |> assign(assigns)
  #    |> assign(:to_circles, new_to_circles)
  #    |> assign_global(
  #      _already_live_selected_:
  #        Enum.uniq(e(assigns(socket), :__context, :_already_live_selected_, []) ++ [:to_circles])
  #    )
  #   }
  # end

  # def handle_info(:clear_flash, socket) do
  #   {:noreply,  socket |> clear_flash()}
  # end

  defp assign_defaults(socket, fun \\ &assign_new/3) do
    current_user =
      current_user(socket) ||
        if Config.env() == :test,
          do:
            Bonfire.UI.Me.LivePlugs.LoadCurrentUser.get_current(
              current_user_id(socket),
              assigns(socket)[:current_account_id]
            )

    socket
    |> assign_global(:current_user, current_user)
    |> fun.(:showing_within, fn -> nil end)
    |> fun.(:context_id, fn -> nil end)
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
    maybe_send(assigns[:__context__] || assigns, persistent_assigns_filter(assigns))
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

    # Promote to_circles from smart_input_opts to top-level so SmartInputContainerLive
    # receives it as the @to_circles prop (not just nested inside @smart_input_opts)
    enriched =
      assigns_map
      |> Map.put(:smart_input_opts, smart_input_opts)
      |> Map.put_new(:smart_input_component, nil)
      |> then(fn m ->
        m
        |> then(fn m ->
          case Map.get(smart_input_opts, :to_circles) do
            nil -> m
            circles -> Map.put_new(m, :to_circles, circles)
          end
        end)
        |> then(fn m ->
          case Map.get(smart_input_opts, :to_boundaries) do
            nil -> m
            boundaries -> Map.put_new(m, :to_boundaries, boundaries)
          end
        end)
        # Always set context_id from smart_input_opts (defaults to nil)
        # so it gets cleared when navigating away from a group page
        |> Map.put(:context_id, Map.get(smart_input_opts, :context_id))
      end)

    maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, enriched)

    # Also assign to PersistentLive's own socket so re-renders pass correct values
    # to SmartInputContainerLive via the template (persistent_live.sface)
    socket =
      socket
      |> assign(
        Map.take(enriched, [
          :to_circles,
          :to_boundaries,
          :context_id,
          :smart_input_opts,
          :smart_input_component
        ])
      )

    # Push JS events for textarea value manipulation and composer visibility
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

    # Open/close the composer via JS (needed because translate-y-100 may have been
    # added client-side by JS.add_class which server re-renders can't remove)
    socket =
      if smart_input_opts[:open] == true do
        open_js =
          %JS{}
          |> JS.remove_class("translate-y-100", to: "#smart_input_container")
          |> JS.show(to: "#composer_container", display: "flex")

        socket
        |> Phoenix.LiveView.push_event("js-exec", %{
          to: "#smart_input_container",
          js: Jason.encode!(open_js.ops)
        })
      else
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
    context = Map.merge(assigns(socket)[:__context__] || %{}, assigns[:__context__] || %{})

    socket =
      socket
      |> assign(assigns)
      |> assign_global(context)
      |> assign_account_users()

    # When smart_input_opts changes via page navigation, sync context_id from it
    # so stale group context gets cleared when navigating away
    socket =
      if Map.has_key?(assigns, :smart_input_opts) do
        opts = assigns[:smart_input_opts] || %{}
        opts = if is_list(opts), do: Map.new(opts), else: opts
        assign(socket, :context_id, Map.get(opts, :context_id))
      else
        socket
      end

    {:noreply, socket}
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

  def handle_info({:process_put_many, entries}, socket)
      when is_list(entries) or is_map(entries) do
    Enum.each(entries, fn {key, value} -> Process.put(key, value) end)
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

  defp assign_account_users(socket) do
    # || if Config.env() == :test, do: Bonfire.UI.Me.LivePlugs.LoadCurrentUser.get_current( current_user_id(socket),   assigns(socket)[:current_account_id])
    current_user = current_user(socket)

    current_account_users =
      assigns(socket)[:current_account_users] ||
        if is_struct(current_user) do
          if Settings.get([Bonfire.Me.Users, :show_switch_users_inline], false,
               current_user: current_user
             ) do
            if account = assigns(socket)[:current_account] || assigns(socket)[:current_account_id] do
              Bonfire.Me.Users.by_account(account)
            end
          end || :skip
        end

    socket
    # |> assign_global(:current_user, current_user)
    |> assign_global(:current_account_users, current_account_users)
  end
end
