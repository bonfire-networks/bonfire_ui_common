defmodule Bonfire.UI.Common.LiveHandlers do
  @moduledoc """
  usage examples:

  `phx-submit="Bonfire.Social.Posts:post"` will be routed to `Bonfire.Social.Posts.LiveHandler.handle_event("post", ...`

  `Bonfire.Common.Utils.pubsub_broadcast(feed_id, {{Bonfire.Social.Feeds, :new_activity}, activity})` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_info({:new_activity, activity}, ...`

  `href="?Bonfire.Social.Feeds[after]=<%= e(@page_info, :end_cursor, nil) %>"` will be routed to `Bonfire.Social.Feeds.LiveHandler.handle_params(%{"after" => cursor_after} ...`

  """
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def handle_params(params, uri, socket, source_module \\ nil) do
    undead(socket, fn ->
      info("LiveHandler: handle_params for #{inspect uri} via #{source_module || "delegation"}")
      ## debug(params: params)
      do_handle_params(params, uri, params_to_socket(params, uri, socket))
    end)
  end

  def handle_event(action, attrs, socket, source_module \\ nil) do
    undead(socket, fn ->
      info("LiveHandler: handle_event #{action} via #{source_module || "delegation"}")
      do_handle_event(action, attrs, socket)
    end)
  end

  def handle_info(blob, socket, source_module \\ nil) do
    undead(socket, fn ->
      info("LiveHandler: handle_info via #{source_module || "delegation"}")
      do_handle_info(blob, socket)
    end)
  end

  # global handler to set a view's assigns from a component
  defp do_handle_info({:assign, {assign, value}}, socket) do
    debug("LiveHandler: do_handle_info, assign data with {:assign, {#{assign}, value}}")
    undead(socket, fn ->
      debug(handle_info_set_assign: assign)
      {:noreply,
        socket
        |> assign_global(assign, value)
        # |> debug(limit: :infinity)
      }
    end)
  end

  defp do_handle_info({{mod, name}, data}, socket) when is_atom(mod) do
    debug("LiveHandler: do_handle_info with {{#{inspect mod}, #{inspect name}}, data}")
    mod_delegate(mod, :handle_info, [{name, data}], socket)
  end

  defp do_handle_info({info, data}, socket) when is_binary(info) do
    debug("LiveHandler: do_handle_info with {#{inspect info}, data}")
    case String.split(info, ":", parts: 2) do
      [mod, name] -> mod_delegate(mod, :handle_info, [{name, data}], socket)
      _ -> empty(socket)
    end
  end

  defp do_handle_info({mod, data}, socket) when is_atom(mod) do
    debug("LiveHandler: do_handle_info with {#{inspect mod}, data}")
    mod_delegate(mod, :handle_info, [data], socket)
  end

  defp do_handle_info(data, socket) do
    warn(data, "LiveHandler: could not find info handler for")
    empty(socket)
  end

  defp do_handle_event(event, attrs, socket) when is_binary(event) do
    # debug(handle_event: event)
    case String.split(event, ":", parts: 2) do
      [mod, action] -> mod_delegate(mod, :handle_event, [action, attrs], socket)
      _ -> empty(socket)
    end
  end

  defp do_handle_event(_, _, socket) do
    warn("LiveHandler: could not find event handler")
    empty(socket)
  end

  defp do_handle_params(params, uri, socket) when is_map(params) and params !=%{} do
    # debug(handle_params: params)
    case Map.keys(params) |> List.first do # first key in a URL query string can be used to indicate the LiveHandler
      mod when is_binary(mod) and mod not in ["id"] -> mod_delegate(mod, :handle_params, [Map.get(params, mod), uri], socket)
      _ -> empty(socket)
    end
  end

  defp do_handle_params(_, _, socket), do: empty(socket)

  def params_to_socket(params, uri, socket) do
    socket
      |> assign_global(
        current_params: params,
        current_url: URI.parse(uri)
                      |> maybe_get(:path)
      )
  end

  defp mod_delegate(mod, fun, params, socket) do
    # debug("attempt delegating to #{inspect fun} in #{inspect mod}...")
    fallback = maybe_to_module(mod)
    case maybe_to_module("#{mod}.LiveHandler") || fallback do
      module when is_atom(module) ->
        info(params, "LiveHandler: delegating to #{inspect fun} in #{module} with params")
        # debug(module)
        if module_enabled?(module) do
          apply(module, fun, params ++ [socket])
        else
          if module !=fallback and module_enabled?(fallback) do
            apply(fallback, fun, params ++ [socket])
          else
            empty(socket)
          end
        end

      _ ->
        error(mod, "LiveHandler: could not find a LiveHandler for")
        empty(socket)
    end
  end

  defp empty(socket), do: {:noreply, socket}
end
