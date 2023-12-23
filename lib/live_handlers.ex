defmodule Bonfire.UI.Common.LiveHandlers do
  @moduledoc """
  usage examples:

  `phx-submit="Bonfire.Social.Posts:post"` will be routed to `Bonfire.Social.Posts.LiveHandler.handle_event("post", ...`

  `PubSub.broadcast(feed_id, {{Bonfire.Social.Feeds, :new_activity}, activity})` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_info({:new_activity, activity}, ...`

  `href="?Bonfire.Social.Feeds[after]=<%= e(@page_info, :end_cursor, nil) %>"` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_params(%{"after" => cursor_after} ...`

  """
  use Bonfire.UI.Common.Web, :live_handler
  alias Bonfire.UI.Common.LivePlugs
  import Untangle

  def handle_params(params, uri, socket, source_module \\ nil, fun \\ nil)
      when is_atom(source_module) do
    undead(socket, fn ->
      debug(
        params,
        "LiveHandler: handle_params for #{inspect(uri)} via #{source_module || "delegation"}"
      )

      # LivePlugs.assign_default_params(params, uri, socket)
      with {:noreply, socket} <-
             do_handle_params(params, uri, socket),
           {:noreply, socket} <-
             if(is_function(fun), do: fun.(params, uri, socket), else: {:noreply, socket}) do
        # in case we're browsing between LVs, send assigns (eg page_title to PersistentLive's process)
        # if socket_connected?(socket), do: LivePlugs.maybe_send_persistent_assigns(socket)

        {:noreply, socket}
      end
    end)
  end

  def handle_event(action, attrs, socket, source_module \\ nil, fun \\ nil) do
    socket
    |> assign_generic(:live_handler_via_module, source_module)
    |> undead(fn ->
      debug("LiveHandler: handle_event #{inspect(action)} via #{source_module || "delegation"}")

      with {:noreply, %{assigns: %{no_live_event_handler: %{^action => true}}} = socket} <-
             do_handle_event(action, attrs, socket),
           {:noreply, socket} <- maybe_handle_event_fun(action, attrs, socket, fun) do
        {:noreply, socket}
      else
        other ->
          # debug(other)
          other
      end
    end)
  end

  def handle_progress(type, entry, socket, source_module, target_fn)
      when is_function(target_fn) do
    socket
    |> assign_generic(:live_handler_via_module, source_module)
    |> undead(fn ->
      target_fn.(type, entry, socket)
    end)
  end

  def handle_progress(type, entry, socket, source_module, target_live_handler)
      when is_atom(target_live_handler) do
    socket
    |> assign_generic(:live_handler_via_module, source_module)
    |> undead(fn ->
      target_live_handler.handle_progress(type, entry, socket)
    end)
  end

  def handle_info(blob, socket, source_module \\ nil) do
    undead(socket, fn ->
      debug("LiveHandler: handle_info via #{source_module || "delegation"}")
      do_handle_info(blob, socket)
    end)
  end

  defp do_handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  # global handler to set a view's assigns from a component
  defp do_handle_info({:assign, {assign, value}}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, {#{assign}, value}}")

    {
      :noreply,
      assign(socket, assign, value)
    }
  end

  defp do_handle_info({:assign, assigns}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, ...}")

    {
      :noreply,
      assign(socket, assigns)
    }
  end

  defp do_handle_info({:assign_global, assigns}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, ...}")

    {
      :noreply,
      assign_global(socket, assigns)
    }
  end

  defp do_handle_info({:assign_persistent, assigns}, socket) do
    debug("LiveHandler: handle_info, send data to PersistentLive with {:assign_persistent, ...}")

    LivePlugs.maybe_send_persistent_assigns(assigns, socket)

    {
      :noreply,
      socket
    }
  end

  defp do_handle_info({{mod, name}, data}, socket) when is_atom(mod) do
    debug("LiveHandler: handle_info with {{#{mod}, #{inspect(name)}}, data}")

    mod_delegate(mod, :handle_info, [{name, data}], socket)
  end

  defp do_handle_info({info, data}, socket) when is_binary(info) do
    debug("LiveHandler: handle_info with {#{info}, data}")

    case String.split(info, ":", parts: 2) do
      [mod, name] -> mod_delegate(mod, :handle_info, [{name, data}], socket)
      _ -> empty(socket)
    end
  end

  defp do_handle_info({mod, data}, socket) when is_atom(mod) do
    debug("LiveHandler: handle_info with {#{mod}, data}")
    mod_delegate(mod, :handle_info, [data], socket)
  end

  defp do_handle_info({_ref, {:phoenix, :send_update, _}}, socket) do
    debug("LiveHandler: send_update completed")
    empty(socket)
  end

  defp do_handle_info({status, _, :process, _, return_status}, socket) do
    info(return_status, "LiveHandler: process #{status}")
    empty(socket)
  end

  defp do_handle_info(data, socket) do
    warn(data, "LiveHandler: could not find info handler for")
    empty(socket)
  end

  # global event handler to set assigns of a view or component
  defp do_handle_event("assign", attrs, socket) do
    {:noreply, assign_attrs(socket, attrs)}
  end

  # helper for when a searches for an option in `LiveSelect`
  defp do_handle_event(
         "live_select_change" = event,
         %{"field" => "multi_select_" <> mod} = data,
         socket
       ) do
    debug("LiveSelect: autocomplete: handle_event with {#{mod}, data}")
    mod_delegate(mod, :do_handle_event, [event, data], socket)
  end

  defp do_handle_event("live_select_change" = event, %{"field" => mod} = data, socket) do
    debug("LiveSelect: autocomplete: handle_event with {#{mod}, data}")
    mod_delegate(mod, :do_handle_event, [event, data], socket)
  end

  # helper for when a user selects an option in `LiveSelect`
  defp do_handle_event(
         action,
         %{"_target" => ["multi_select", module], "multi_select" => params},
         socket
       )
       when action in ["select", "change", "validate", "multi_select"] do
    debug(
      params,
      "LiveSelect: select an option: try to delegate to `#{module}` (should be the module/component that is handling this multi_select)"
    )

    input_name = module <> "_text_input"

    case params do
      %{^module => "", ^input_name => _} ->
        {:noreply, socket}

      %{^module => data, ^input_name => text} when is_binary(data) ->
        mod_delegate(
          module,
          :do_handle_event,
          ["multi_select", %{text: text, data: maybe_from_json(data)}],
          socket
        )

      %{^module => data, ^input_name => text} when is_list(data) ->
        mod_delegate(
          module,
          :do_handle_event,
          ["multi_select", %{text: text, data: Enum.map(data, &maybe_from_json/1)}],
          socket
        )

      _ ->
        warn(params, "Unrecognised event from LiveSelect")
        {:noreply, socket}
    end
  end

  defp do_handle_event(event, attrs, socket) when is_binary(event) do
    # debug(handle_event: event)
    case String.split(event, ":", parts: 2) do
      [module, action] ->
        do_handle_event({module, action}, attrs, socket)

      _ ->
        debug(attrs, "attrs")
        no_live_handler({:handle_event, event}, socket)
    end
  end

  defp do_handle_event({module, action}, attrs, socket) do
    mod_delegate(module, :handle_event, [action, attrs], socket)
  end

  defp do_handle_event(event, attrs, socket) do
    debug(attrs, "attrs")
    no_live_handler({:handle_event, event}, socket)
  end

  defp maybe_handle_event_fun(action, attrs, socket, fun) when is_function(fun) do
    fun.(action, attrs, socket)
  end

  defp maybe_handle_event_fun(action, _attrs, socket, _fun) do
    warn(action, "LiveHandler: could not find an event handler")
    {:noreply, socket}
  end

  defp do_handle_params(params, uri, socket)
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

  defp do_handle_params(_, _, socket), do: empty(socket)

  def mod_delegate(mod, fun, args, socket) do
    # debug("attempt delegating to #{inspect fun} in #{inspect mod}...")
    fallback =
      if(is_atom(mod), do: mod, else: maybe_to_module(mod))
      |> debug("fallback")

    case maybe_to_module("#{mod}.LiveHandler") || fallback do
      module when is_atom(module) and not is_nil(module) ->
        if module_enabled?(module) do
          debug(
            args,
            "LiveHandler: delegating to #{inspect(fun)} in #{module} with args"
          )

          apply(module, fun, args ++ [socket])
          # |> debug("applied")
        else
          if module != fallback and module_enabled?(fallback) do
            debug(
              args,
              "LiveHandler: delegating to fallback module #{inspect(fallback)} in #{module} with args"
            )

            apply(fallback, fun, args ++ [socket])
          else
            warn(module, "LiveHandler: handler module not enabled")
            no_live_handler({fun, List.first(args)}, socket)
          end
        end

      _ ->
        warn(mod, "LiveHandler: could not find a LiveHandler for")
        no_live_handler({fun, List.first(args)}, socket)
    end
  end

  defp no_live_handler({:handle_event, event}, socket),
    do:
      {:noreply,
       socket
       |> assign_generic(
         :no_live_event_handler,
         (socket.assigns[:no_live_event_handler] || %{}) |> Map.put(event, true)
       )}

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
