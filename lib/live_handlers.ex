defmodule Bonfire.UI.Common.LiveHandlers do
  @moduledoc """
  usage examples:

  `phx-submit="Bonfire.Social.Posts:post"` will be routed to `Bonfire.Social.Posts.LiveHandler.handle_event("post", ...`

  `PubSub.broadcast(feed_id, {{Bonfire.Social.Feeds, :new_activity}, activity})` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_info({:new_activity, activity}, ...`

  `href="?Bonfire.Social.Feeds[after]=<%= e(@page_info, :end_cursor, nil) %>"` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_params(%{"after" => cursor_after} ...`

  """
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  def handle_params(params, uri, socket, source_module \\ nil, fun \\ nil)
      when is_atom(source_module) do
    undead(socket, fn ->
      debug(
        params,
        "LiveHandler: handle_params for #{inspect(uri)} via #{source_module || "delegation"}"
      )

      with {:noreply, socket} <-
             do_handle_params(params, uri, assign_default_params(params, uri, socket)),
           {:noreply, socket} <-
             if(is_function(fun), do: fun.(params, uri, socket), else: {:noreply, socket}) do
        # in case we're browsing between LVs, send assigns (eg page_title to PersistentLive's process)
        if socket_connected?(socket),
          do:
            Bonfire.UI.Common.PersistentLive.maybe_send_assigns(
              socket.assigns
              # |> Map.put_new(:nav_items, nil)
            )

        {:noreply, socket}
      end
    end)
  end

  def handle_event(action, attrs, socket, source_module \\ nil, fun \\ nil) do
    undead(socket, fn ->
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

  def handle_info(blob, socket, source_module \\ nil) do
    undead(socket, fn ->
      debug("LiveHandler: handle_info via #{source_module || "delegation"}")
      do_handle_info(blob, socket)
    end)
  end

  # global handler to set a view's assigns from a component
  defp do_handle_info({:assign, {assign, value}}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, {#{assign}, value}}")

    {
      :noreply,
      assign_global(socket, assign, value)
    }
  end

  defp do_handle_info({:assign, assigns}, socket) do
    debug("LiveHandler: handle_info, assign data with {:assign, ...}")

    {
      :noreply,
      assign_global(socket, assigns)
    }
  end

  defp do_handle_info({:assign_persistent, assigns}, socket) do
    debug("LiveHandler: handle_info, send data to PersistentLive with {:assign_persistent, ...}")

    Bonfire.UI.Common.PersistentLive.maybe_send_assigns(assigns)

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

  defp do_handle_info(%LiveSelect.ChangeMsg{field: mod} = data, socket) when is_atom(mod) do
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
    debug(attrs, "LiveHandler: simple assign")
    {:noreply, assign_global(socket, attrs)}
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
      "try to delegate to `#{module}` (should be the module/component that is handling this multi_select)"
    )

    input_name = module <> "_text_input"

    case params do
      %{^module => "", ^input_name => _} ->
        {:noreply, socket}

      %{^module => data, ^input_name => text} ->
        with {:ok, data} <- Jason.decode(data) do
          mod_delegate(module, :handle_event, ["multi_select", %{text: text, data: data}], socket)
        else
          e ->
            error(e)

            mod_delegate(
              module,
              :handle_event,
              ["multi_select", %{text: text, data: data}],
              socket
            )
        end
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

  def assign_default_params(params, uri, socket) do
    assign_global(
      socket,
      current_params: params,
      current_url:
        URI.parse(uri)
        |> maybe_get(:path)
    )

    # see also more assigns set in `LivePlugs.apply_undead_mounted`
  end

  def mod_delegate(mod, fun, args, socket) do
    # debug("attempt delegating to #{inspect fun} in #{inspect mod}...")
    fallback = maybe_to_module(mod)

    case maybe_to_module("#{mod}.LiveHandler") || fallback do
      module when is_atom(module) ->
        if module_enabled?(module) do
          info(
            args,
            "LiveHandler: delegating to #{inspect(fun)} in #{module} with args"
          )

          apply(module, fun, args ++ [socket])
          # |> debug("applied")
        else
          if module != fallback and module_enabled?(fallback) do
            info(
              args,
              "LiveHandler: delegating to #{inspect(fallback)} in #{module} with args"
            )

            apply(fallback, fun, args ++ [socket])
          else
            no_live_handler({fun, List.first(args)}, socket)
          end
        end

      _ ->
        error(mod, "LiveHandler: could not find a LiveHandler for")
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
end
