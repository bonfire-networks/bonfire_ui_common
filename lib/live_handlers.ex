defmodule Bonfire.UI.Common.LiveHandlers do
  @moduledoc """
  LiveHandlers provides a standardized way to handle various LiveView events (params, events, info) and route them to appropriate handler modules, enabling you to easily handle the same event in multiple live views or components using the same code.

  ## Types of handlers

  - Events (eg. clicks or form submissions)
  - URL parameters
  - PubSub messages

  ## Features

  - Routing events to specific LiveHandler modules based on naming conventions
  - Automatic error handling with `ErrorHandling.undead/2`
  - Built-in handlers for common operations (assign, redirect, etc.)
  - Support for direct function delegation


  ## Usage Examples

  ### Event Delegation

  ```elixir
  # In your template:
  phx-submit="Bonfire.Posts:post"
  # Will be routed to:
  Bonfire.Posts.LiveHandler.handle_event("post", params, socket)
  ```

  ### PubSub Handling

  ```elixir
  # When broadcasting:
  PubSub.broadcast(feed_id, {{Bonfire.Social.Feeds, :new_activity}, activity})
  # Will be routed to:
  Bonfire.Social.Feeds.LiveHandler.handle_info({:new_activity, activity}, socket)
  ```

  ### URL Parameter Handling

  ```elixir
  # For a URL like:
  "?Bonfire.Social.Feeds[after]=cursor123"
  # Will be routed to:
  Bonfire.Social.Feeds.LiveHandler.handle_params(%{"after" => "cursor123"}, uri, socket)
  ```
  """

  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  alias Bonfire.UI.Common.LivePlugs
  alias Bonfire.UI.Common.ErrorHandling

  @doc """
  Handles URL parameters and delegates to appropriate LiveHandler modules.

  This function first checks if a specific handler function was provided, then attempts to
  delegate to a LiveHandler module based on URL query parameters.

  ## Parameters

  - `params`: Map of URL query parameters
  - `uri`: Current URI string
  - `socket`: The Phoenix LiveView socket
  - `source_module`: (optional) The source module making the call
  - `fun`: (optional) Custom function to handle the params before attempting delegation

  ## Examples

  ```elixir
  # When handling a URL like "?Bonfire.Users[filter]=active"
  handle_params(%{"Bonfire.Users" => %{"filter" => "active"}}, "/users", socket)
  # Delegates to:
  Bonfire.Users.LiveHandler.handle_params(%{"filter" => "active"}, "/users", socket)
  ```

  ## Returns

  `{:noreply, socket}`
  """
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

  @doc """
  Handles messages sent to the LiveView process and delegates to appropriate handlers.

  This function processes messages based on their structure and delegates to the appropriate
  LiveHandler module.

  ## Parameters

  - `blob`: The message being handled
  - `socket`: The Phoenix LiveView socket
  - `source_module`: (optional) The source module making the call
  - `fun`: (optional) Custom function to handle the message before delegation

  ## Built-in Message Handlers (handled directly with no delegation necessary)

  - `:clear_flash` - Clears all flash messages
  - `{:assign, {key, value}}` - Assigns a single key-value pair to the socket
  - `{:assign, assigns}` - Assigns multiple values to the socket
  - `{:assign_global, assigns}` - Assigns global values (using Surface's `@__context__`)
  - `{:assign_persistent, assigns}` - Sends assigns to PersistentLive
  - `{:redirect, to}` - Redirects to the specified path
  - `{{module, name}, data}` - Delegates to a LiveHandler

  ## Examples

  ```elixir
  # Assign a value on the current LiveView
  send(self(), {:assign, {key: :value}})

  # Send a message to be handled by a specific LiveHandler
  send(self(), {{Bonfire.Posts, :new_post}, post})
  # Delegates to:
  Bonfire.Posts.LiveHandler.handle_info({:new_post, post}, socket)
  ```

  ## Returns

  `{:noreply, socket}`
  """
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

  @doc """
  Handles LiveView events and delegates to appropriate LiveHandler modules.

  This function processes events based on their name and delegates to the appropriate
  LiveHandler module.

  ## Parameters

  - `action`: The event name or `{module, action}` tuple
  - `attrs`: The event parameters
  - `socket`: The Phoenix LiveView socket
  - `source_module`: (optional) The source module making the call
  - `fun`: (optional) Custom function to handle the event before delegation

  ## Built-in Event Handlers

  - `"assign"` - Assigns values from the event parameters to the socket
  - `"redirect"` or `"navigate"` - Redirects to the specified path
  - `"live_select_change"` - Handles `LiveSelect` component events

  ## Examples

  ```elixir
  # From a template:
  phx-click="Bonfire.Posts:like"
  # Delegates to:
  Bonfire.Posts.LiveHandler.handle_event("like", params, socket)
  ```

  ## Returns

  `{:noreply, socket}`
  """
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

  @doc """
  Handles upload progress events, delegating to a function or LiveHandler module.

  This function handles upload progress events and delegates to either a function or a
  LiveHandler module.

  ## Parameters

  - `type`: The type of upload (e.g., `:avatar`, `:image`)
  - `entry`: The upload entry containing progress information
  - `socket`: The Phoenix LiveView socket
  - `source_module`: The source module making the call
  - `target_fn`: Function to handle the progress event

  ## Examples

  ```elixir
  # Delegating to a function:
  handle_progress(:avatar, entry, socket, __MODULE__, &handle_avatar_upload/3)

  # Define the handler function:
  def handle_avatar_upload(type, entry, socket) do
    # Process avatar upload
    {:noreply, socket}
  end
  ```

  ```elixir
  # Delegate to a module:
  handle_progress(:avatar, entry, socket, __MODULE__, MyLiveHandler)

  # Define the handler function in `MyLiveHandler`:
  def handle_progress(type, entry, socket) do
    # Process avatar upload
    {:noreply, socket}
  end
  ```

  ## Returns

  Result of the target function, typically `{:noreply, socket}`
  """
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
    # first key in a URL query string can be used to indicate the LiveHandler
    case Map.keys(params) |> List.first() do
      mod when is_binary(mod) and mod not in ["id"] ->
        # debug(mod, "mod")
        mod_delegate(mod, :handle_params, [Map.get(params, mod), uri], socket)

      _ ->
        empty(socket)
    end
  end

  defp maybe_delegate_handle_params(_, _, socket), do: empty(socket)

  @doc """
  Delegates a function call to a module's LiveHandler.

  This function attempts to find and call a function in a module's LiveHandler, with
  proper error handling and circular reference detection.

  ## Parameters

  - `mod`: Module name (string or atom)
  - `fun`: Function name (atom)
  - `args`: Function arguments
  - `socket`: The Phoenix LiveView socket
  - `no_delegation_fn`: (optional) Function to call if delegation fails

  ## Examples

  ```elixir
  # Delegate to a LiveHandler:
  mod_delegate("Bonfire.Posts", :handle_event, ["like", %{id: 123}], socket)
  # Calls:
  Bonfire.Posts.LiveHandler.handle_event("like", %{id: 123}, socket)
  ```

  ## Returns

  Result of the delegated function call, for example `{:noreply, socket}`
  """
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
              socket = assign_generic(socket, :__handler_chain, handler_chain ++ [mod])

              apply(module, fun, args ++ [socket])
              # |> debug("applied")
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
          {:noreply, assign_generic(socket, :__handler_chain, [])}

        {:error, e} ->
          {:error, e}

        {reply, %{} = socket} ->
          {reply, assign_generic(socket, :__handler_chain, [])}

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

  @doc """
  Assigns socket values based on event attributes.

  This function processes a map of attributes and assigns them to the socket, with
  options for converting to atoms and global assignment.

  ## Parameters

  - `socket`: The Phoenix LiveView socket
  - `attrs`: Map of attributes to assign

  ## Options (in attrs)

  - `"to_atoms"`: Convert keys to atoms (true/false)
  - `"to_integers"`: Convert values to integers (true/false)
  - `"assign_global"`: Make global assigns (true/false)
  - `"send_self"`: Send assigns to self (true/false)

  ## Examples

  ```elixir
  # Simple assignment:
  assign_attrs(socket, %{"name" => "User", "age" => "42"})

  # With conversion options:
  assign_attrs(socket, %{"name" => "User", "age" => "42", "to_atoms" => "true", "to_integers" => "true"})
  ```

  ## Returns

  Socket with assigned values
  """
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

  @doc """
  Converts a JSON string to a map if it appears to be valid JSON.

  ## Parameters

  - `json`: String that might be JSON

  ## Examples

  ```elixir
  iex> Bonfire.UI.Common.LiveHandlers.maybe_from_json("{\"name\":\"test\"}")
  %{"name" => "test"}

  iex> Bonfire.UI.Common.LiveHandlers.maybe_from_json("not json")
  "not json"
  ```

  ## Returns

  Decoded JSON map or the original value
  """
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
