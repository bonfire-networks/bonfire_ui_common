defmodule Bonfire.UI.Common.LiveHandlers do
  @moduledoc """
  usage examples:

  `phx-submit="Bonfire.Posts:post"` will be routed to `Bonfire.Posts.LiveHandler.handle_event("post", ...`

  `PubSub.broadcast(feed_id, {{Bonfire.Social.Feeds, :new_activity}, activity})` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_info({:new_activity, activity}, ...`

  `href="?Bonfire.Social.Feeds[after]=<%= e(@page_info, :end_cursor, nil) %>"` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_params(%{"after" => cursor_after} ...`

  """
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  alias Bonfire.UI.Common.LivePlugs
  alias Bonfire.UI.Common.ErrorHandling

  def handle_params(params, uri, socket, source_module \\ nil, fun \\ nil)
      when is_atom(source_module) do
    ErrorHandling.undead(socket, fn ->
      debug(
        params,
        "LiveHandler: handle_params for #{inspect(uri)} via #{source_module || "delegation"}"
      )

      # debug(fun)

      # LivePlugs.assign_default_params(params, uri, socket)
      with {:noreply, socket} <-
             if(is_function(fun, 3), do: fun.(params, uri, socket), else: {:noreply, socket}),
           {:noreply, socket} <-
             maybe_delegate_handle_params(params, uri, socket) do
        # in case we're browsing between LVs, send assigns (eg page_title to PersistentLive's process)
        # if socket_connected?(socket), do: LivePlugs.maybe_send_persistent_assigns(socket)

        {:noreply, socket}
      end
    end)
  end

  def handle_info(blob, socket, source_module \\ nil, fun \\ nil) do
    ErrorHandling.undead(socket, fn ->
      debug("LiveHandler: handle_info via #{source_module || "delegation"}")

      with {:noreply, %{assigns: %{__no_handle_info_handled__: true}} = socket} <-
             maybe_handle_info(blob, socket),
           socket = assign(socket, :__no_handle_info_handled__, nil),
           {:noreply, socket} <-
             if(is_function(fun, 2), do: fun.(blob, socket), else: {:noreply, socket}) do
        # in case we're browsing between LVs, send assigns (eg page_title to PersistentLive's process)
        # if socket_connected?(socket), do: LivePlugs.maybe_send_persistent_assigns(socket)

        {:noreply, socket}
      end
    end)
  end

  def handle_event(action, attrs, socket, source_module \\ nil, fun \\ nil) do
    socket
    |> assign_generic(:live_handler_via_module, source_module)
    |> ErrorHandling.undead(fn ->
      debug("LiveHandler: handle_event #{inspect(action)} via #{source_module || "delegation"}")

      with {:noreply, %{assigns: %{__no_live_event_handler__: %{^action => true}}} = socket} <-
             maybe_delegate_event_live_handler(action, attrs, socket),
           {:noreply, socket} <-
             maybe_module_provided_handle_event_fun(action, attrs, socket, fun) do
        #  {:noreply, socket} <- maybe_delegate_event_live_handler(action, attrs, socket) do
        {:noreply, socket}
      end
    end)
  end

  def handle_progress(type, entry, socket, source_module, target_fn)
      when is_function(target_fn) do
    socket
    |> assign_generic(:live_handler_via_module, source_module)
    |> ErrorHandling.undead(fn ->
      target_fn.(type, entry, socket)
    end)
  end

  def handle_progress(type, entry, socket, source_module, target_live_handler)
      when is_atom(target_live_handler) do
    socket
    |> assign_generic(:live_handler_via_module, source_module)
    |> ErrorHandling.undead(fn ->
      target_live_handler.handle_progress(type, entry, socket)
    end)
  end

  defp maybe_handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  # global handler to set a view's assigns from a component
  defp maybe_handle_info({:assign, {assign, value}}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, {#{assign}, value}}")

    {
      :noreply,
      assign(socket, assign, value)
    }
  end

  defp maybe_handle_info({:assign, assigns}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, ...}")

    {
      :noreply,
      assign(socket, assigns)
    }
  end

  defp maybe_handle_info({:assign_global, assigns}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, ...}")

    {
      :noreply,
      assign_global(socket, assigns)
    }
  end

  defp maybe_handle_info({:assign_persistent, assigns}, socket) do
    debug("LiveHandler: handle_info, send data to PersistentLive with {:assign_persistent, ...}")

    LivePlugs.maybe_send_persistent_assigns(assigns, socket)

    {
      :noreply,
      socket
    }
  end

  defp maybe_handle_info({:redirect, to}, socket) do
    debug("LiveHandler: handle_info, redirect at view level")

    {
      :noreply,
      socket
      |> redirect_to(to)
    }
  end

  defp maybe_handle_info({{mod, name}, data}, socket) when is_atom(mod) do
    debug("LiveHandler: handle_info with {{#{mod}, #{inspect(name)}}, data}")

    mod_delegate(mod, :handle_info, [{name, data}], socket, &no_handle_info/2)
  end

  defp maybe_handle_info({info, data}, socket) when is_binary(info) do
    case String.split(info, ":", parts: 2) do
      [mod, name] ->
        debug("LiveHandler: handle_info with {#{info}, data}")
        mod_delegate(mod, :handle_info, [{name, data}], socket, &no_handle_info/2)

      _ ->
        debug("LiveHandler: handle_info with no module/fun to delegate to")
        no_handle_info(socket)
    end
  end

  defp maybe_handle_info({mod, data}, socket) when is_atom(mod) do
    debug("LiveHandler: handle_info with {#{mod}, data}")
    mod_delegate(mod, :handle_info, [data], socket, &no_handle_info/2)
  end

  defp maybe_handle_info({_ref, {:phoenix, :send_update, _}}, socket) do
    debug("LiveHandler: send_update completed")
    empty(socket)
  end

  defp maybe_handle_info({status, _, :process, _, return_status}, socket) do
    info(return_status, "LiveHandler: process #{status}")
    empty(socket)
  end

  defp maybe_handle_info(data, socket) do
    warn(data, "LiveHandler: could not find info handler for")
    no_handle_info(socket)
  end

  defp no_handle_info(_other \\ nil, socket) do
    {:noreply,
     socket
     |> assign_generic(
       :__no_handle_info_handled__,
       true
     )}
  end

  # global event handler to set assigns of a view or component
  defp maybe_delegate_event_live_handler("assign", attrs, socket) do
    {:noreply, assign_attrs(socket, attrs)}
  end

  defp maybe_delegate_event_live_handler(redir_action, %{"to" => to}, socket)
       when redir_action in ["redirect", "navigate"] and is_binary(to) do
    debug(to, "LiveHandler: handle_event, redirect")

    {
      :noreply,
      socket
      |> redirect_to(to)
    }
  end

  # helper for when a searches for an option in `LiveSelect`
  defp maybe_delegate_event_live_handler(
         "live_select_change" = event,
         %{"field" => "multi_select_" <> mod} = data,
         socket
       ) do
    debug("LiveSelect: autocomplete: handle_event with {#{mod}, data}")
    debug(data, "data")
    mod_delegate(mod, :handle_event, [event, data], socket)
  end

  defp maybe_delegate_event_live_handler(
         "live_select_change" = event,
         %{"field" => mod} = data,
         socket
       ) do
    debug("LiveSelect: autocomplete: handle_event with {#{mod}, data}")
    mod_delegate(mod, :handle_event, [event, data], socket)
  end

  # helper for when a user selects an option in `LiveSelect`
  defp maybe_delegate_event_live_handler(
         action,
         %{"_target" => ["multi_select", module], "multi_select" => params},
         socket
       )
       when action in ["select", "change", "validate", "multi_select"] do
    debug(
      params,
      "LiveSelect: select an option: try to delegate to `#{module}` (should be the module/component that is handling this multi_select)"
    )

    maybe_delegate_live_select(module <> "_text_input", module, params, socket) ||
      maybe_delegate_live_select(module <> "_empty_selection", module, params, socket) ||
      (
        warn(params, "Unrecognised event from LiveSelect")
        {:noreply, socket}
      )
  end

  defp maybe_delegate_event_live_handler(event, attrs, socket) when is_binary(event) do
    # debug(handle_event: event)
    case String.split(event, ":", parts: 2) do
      [module, action] ->
        handle_event({module, action}, attrs, socket)

      _ ->
        debug(attrs, "attrs")
        no_live_handler({:handle_event, event}, socket)
    end
  end

  defp maybe_delegate_event_live_handler({module, action}, attrs, socket) do
    mod_delegate(module, :handle_event, [action, attrs], socket)
  end

  defp maybe_delegate_event_live_handler(event, attrs, socket) do
    debug(attrs, "attrs")
    no_live_handler({:handle_event, event}, socket)
  end

  defp maybe_delegate_live_select(input_name, module, params, socket) do
    case params do
      %{^module => "", ^input_name => _} ->
        {:noreply, socket}

      %{^module => data, ^input_name => text} when is_binary(data) ->
        mod_delegate(
          module,
          :handle_event,
          ["multi_select", %{text: text, data: maybe_from_json(data)}],
          socket
        )

      %{^module => data, ^input_name => text} when is_list(data) ->
        mod_delegate(
          module,
          :handle_event,
          ["multi_select", %{text: text, data: Enum.map(data, &maybe_from_json/1)}],
          socket
        )

      #  TODO: how do we known the input name
      %{^input_name => ""} ->
        mod_delegate(
          module,
          :handle_event,
          ["multi_select", %{data: nil}],
          socket
        )

      _ ->
        nil
    end
  end

  defp maybe_module_provided_handle_event_fun(action, attrs, socket, fun)
       when is_function(fun, 3) do
    fun.(action, attrs, socket)
  end

  defp maybe_module_provided_handle_event_fun(action, attrs, socket, _fun) do
    debug(
      attrs,
      "LiveHandler: no handle_event action `#{action}` defined in module, will try LiveHandlers instead"
    )

    {:noreply, socket}
  end

  defp maybe_delegate_handle_params(params, uri, socket)
       when is_map(params) and params != %{} do
    # debug(handle_params: params)
    # first key in a URL query string can be used to indicate the LiveHandler
    case Map.keys(params) |> List.first() do
      mod when is_binary(mod) and mod not in ["id"] ->
        mod_delegate(mod, :handle_params, [Map.get(params, mod), uri], socket)

      _ ->
        empty(socket)
    end
  end

  defp maybe_delegate_handle_params(_, _, socket), do: empty(socket)

  def mod_delegate(mod, fun, args, socket, no_delegation_fn \\ &no_live_handler/2) do
    handler_chain = Map.get(socket.assigns, :__handler_chain, [])

    mod = maybe_to_module("#{mod}.LiveHandler") || maybe_to_module(mod)

    if mod in handler_chain do
      warn("Circular handler delegation detected: #{inspect(handler_chain ++ [mod])}")
      no_delegation_fn.({fun, List.first(args)}, socket)
    else
      # Delegation logic
      result =
        case mod do
          module when is_atom(module) and not is_nil(module) ->
            if module_enabled?(module, socket) and
                 function_exported?(module, fun, length(args) + 1) do
              debug(args, "LiveHandler: delegating to #{inspect(fun)} in #{module} with args")
              socket = assign(socket, :__handler_chain, handler_chain ++ [mod])

              apply(module, fun, args ++ [socket])
              |> debug("applied")
            else
              warn(module, "LiveHandler: handler module not enabled or function not exported")
              no_delegation_fn.({fun, List.first(args)}, socket)
            end

          _ ->
            debug(mod, "LiveHandler: no handler to delegate to")
            no_delegation_fn.({fun, List.first(args)}, socket)
        end

      # Reset the handler chain in the returned socket

      case result do
        {:noreply, socket} ->
          {:noreply, assign(socket, :__handler_chain, [])}

        {:error, e} ->
          {:error, e}

        {reply, %{} = socket} ->
          {reply, assign(socket, :__handler_chain, [])}

        other ->
          other
      end
    end
  end

  defp clean_no_handler_map(socket) do
    current = assigns(socket)[:__no_live_event_handler__] || %{}
    # arbitrary limit
    if map_size(current) > 100 do
      debug("LiveHandler: cleaning up __no_live_event_handler__ map")
      assign_generic(socket, :__no_live_event_handler__, %{})
    else
      socket
    end
  end

  defp no_live_handler({:handle_event, event}, socket) do
    socket
    |> clean_no_handler_map()
    |> assign_generic(
      :__no_live_event_handler__,
      (assigns(socket)[:__no_live_event_handler__] || %{}) |> Map.put(event, true)
    )
    |> empty()
  end

  defp no_live_handler(_, socket), do: empty(socket)
  defp empty(socket), do: {:noreply, socket}

  def assign_attrs(socket, attrs) do
    attrs
    |> Map.drop(["to_atoms", "assign_global", "send_self", "value"])
    |> debug("LiveHandler: attrs")
    |> (fn assigns ->
          if attrs["to_atoms"] == "true",
            do:
              input_to_atoms(assigns,
                discard_unknown_keys: true,
                values: true,
                values_to_integers: attrs["to_integers"] == "true"
              ),
            else:
              input_to_atoms(assigns,
                discard_unknown_keys: true,
                values: false,
                values_to_integers: attrs["to_integers"] == "true"
              )
        end).()
    |> debug("LiveHandler: simple assign")
    |> (fn assigns ->
          if attrs["send_self"] == "true", do: send_self(assigns)

          if attrs["assign_global"] == "true",
            do: assign_global(socket, assigns),
            else: assign_generic(socket, assigns)
        end).()
  end

  def maybe_from_json("{" <> _ = json) do
    with {:ok, data} <- Jason.decode(json) do
      data
    else
      e ->
        warn(e)
        json
    end
  end

  def maybe_from_json(other), do: other
end
