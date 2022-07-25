defmodule Bonfire.UI.Common do
  @moduledoc """
  A library of common utils and helpers used across Bonfire extensions
  """
  use Bonfire.Common.Utils

  defmacro __using__(opts) do
    # TODO: pass opts to the nested `use`
    quote do
      use Bonfire.Common.Utils
      import Bonfire.UI.Common
    end
  end

  def assign_generic(%Phoenix.LiveView.Socket{} = socket, assigns) do
    Phoenix.LiveView.assign(socket, assigns)
  end
  def assign_generic(%Plug.Conn{} = conn, assigns) do
    Plug.Conn.merge_assigns(conn, maybe_to_keyword_list(assigns, false))
  end
  def assign_generic(%Phoenix.LiveView.Socket{} = socket, key, value) do
    Phoenix.LiveView.assign(socket, key, value)
  end
  def assign_generic(%Plug.Conn{} = conn, key, value) do
    Plug.Conn.assign(conn, key, value)
  end

  def assign_global(socket, assigns) when is_map(assigns) do
    # assign_global(socket, Map.to_list(assigns))
    Enum.reduce(
      assigns,
      socket,
      fn {k, v}, socket -> assign_global(socket, k, v) end
    )
  end
  def assign_global(socket, assigns) when is_list(assigns) do
    socket
    |> assign_generic(assigns)
    # being naughty here, let's see how long until Surface breaks it:
    |> assign_generic(:__context__,
                          Map.get(socket.assigns, :__context__, %{})
                          |> Map.merge(maybe_to_map(assigns))
    ) #|> debug("assign_global")
  end
  def assign_global(socket, {_, _} = assign) do
    assign_global(socket, Keyword.new([assign]))
  end

  def assign_global(socket, key, value) when is_atom(key) do
    assign_global(socket, Keyword.new([{key, value}]))
  end
  def assign_global(socket, key, value) when is_binary(key) do
    case maybe_to_atom(key) do
      key when is_atom(key) -> assign_global(socket, Keyword.new([{key, value}]))
      _ ->
        warn(key, "Could not assign (not an existing atom)")
        socket
    end
  end
  # def assign_global(socket, assign, value) do
  #   socket
  #   |> assign_generic(assign, value)
  #   |> assign_generic(:global_assigns, [assign] ++ Map.get(socket.assigns, :global_assigns, []))
  # end

  # TODO: get rid of assigning everything to a component, and then we'll no longer need this
  def assigns_clean(%{} = assigns) when is_map(assigns), do: assigns_clean(Map.to_list(assigns))
  def assigns_clean(assigns) do
    (
    assigns
    ++ [{:current_user, current_user(assigns)}]
    ) # temp workaround
    # |> IO.inspect
    |> Enum.reject( fn
      {key, _} when key in [
        :id,
        :flash,
        :__changed__,
        # :__context__,
        :__surface__,
        :socket
      ] -> true
      _ -> false
    end)
    # |> IO.inspect
  end

  def assigns_minimal(%{} = assigns) when is_map(assigns), do: assigns_minimal(Map.to_list(assigns))
  def assigns_minimal(assigns) do

    preserve_global_assigns = Keyword.get(assigns, :global_assigns, []) || [] #|> IO.inspect

    assigns
    # |> IO.inspect
    |> Enum.reject( fn
      {:current_user, _} -> false
      {:current_account, _} -> false
      {:global_assigns, _} -> false
      {assign, _} -> assign not in preserve_global_assigns
      _ -> true
    end)
    # |> IO.inspect
  end

  def assigns_merge(%Phoenix.LiveView.Socket{} = socket, assigns, new) when is_map(assigns) or is_list(assigns), do: socket |> assign_generic(assigns_merge(assigns, new))
  def assigns_merge(assigns, new) when is_map(assigns), do: assigns_merge(Map.to_list(assigns), new)
  def assigns_merge(assigns, new) when is_map(new), do: assigns_merge(assigns, Map.to_list(new))
  def assigns_merge(assigns, new) when is_list(assigns) and is_list(new) do

    assigns
    |> assigns_clean()
    |> deep_merge(new)
    # |> IO.inspect
  end


  def rich(content) do
    case content do
      _ when is_binary(content) ->

        content
        # |> Text.maybe_markdown_to_html() # now being done on save instead
        |> Text.normalise_links() # transform internal links to use LiveView navigation
        |> Phoenix.HTML.raw() # for use in views

      {:ok, msg} when is_binary(msg) -> msg
      {:ok, _} ->
        debug(content)
        l "Ok"
      {:error, msg} when is_binary(msg) ->
        error(msg)
        msg
      {:error, _} ->
        error(content)
        l "Error"
      _ when is_map(content) ->
        error(content, "Unexpected data")
        l "Unexpected data"
      _ when is_nil(content) or content=="" -> nil
      %Ecto.Association.NotLoaded{} -> nil
      _  -> inspect content
    end
  end

  def markdown(content) when is_binary(content) do
    content
    |> Text.maybe_markdown_to_html()
    |> rich()
  end
  def markdown(content) do
    rich(content)
  end

  def templated(content, data \\ nil)
  def templated(content, data) when is_binary(content) do
    content
    |> Text.maybe_render_templated(data)
    |> Text.maybe_markdown_to_html()
    |> rich()
  end
  def templated(content, _data) do
    rich(content)
  end

  def templated_or_remote_markdown(content, data \\ nil) do
    debug(content)
    if Bonfire.Common.URIs.is_uri?(content) do
      with {:ok, %{body: body}} when is_binary(body) <- Bonfire.Common.HTTP.get_cached(content) do
        templated(body, data)
      else e ->
        debug(e, "Could not fetch remote content")
        templated(content, data)
      end
    else
      templated(content, data)
    end
  end

  def current_url(socket_or_assigns, default \\ nil) do
    case socket_or_assigns do
      %{current_url: url} when is_binary(url) -> url
      %{context: context}       = _api_opts   -> current_url(context, default)
      %{__context__: context}   = _assigns    -> current_url(context, default)
      %{assigns: assigns}       = _socket     -> current_url(assigns, default)
      %{socket: socket}         = _socket     -> current_url(socket, default)
      url when is_binary(url)                 -> url
      options when is_list(options)           -> current_url(Map.new(options), default)
      other ->
        debug("No current_url found in #{inspect other}")
        default
    end
  end

  # defdelegate content(conn, name, type, opts \\ [do: ""]), to: Bonfire.UI.Common.ContentAreas

  @doc """
  Special LiveView helper function which allows loading LiveComponents in regular Phoenix views: `live_render_component(@conn, MyLiveComponent)`
  """
  def live_render_component(conn, load_live_component) do
    if module_enabled?(load_live_component),
      do:
        Phoenix.LiveView.Controller.live_render(
          conn,
          Bonfire.UI.Common.LiveComponent,
          session: %{
            "load_live_component" => load_live_component
          }
        )
  end

  def live_render_with_conn(conn, live_view) do
    Phoenix.LiveView.Controller.live_render(conn, live_view, session: %{"conn" => conn})
  end

  defp socket_connected_or_user?(%Phoenix.LiveView.Socket{}), do: true
  defp socket_connected_or_user?(other), do: if current_user(other), do: true, else: false


  @doc """
  Subscribe to something for realtime updates, like a feed or thread
  """
  # def pubsub_subscribe(topics, socket \\ nil)

  def pubsub_subscribe(topics, socket) when is_list(topics) do
    Enum.each(topics, &pubsub_subscribe(&1, socket))
  end

  def pubsub_subscribe(topic, socket_etc) when is_binary(topic) do
    # debug(socket)
    if socket_connected_or_user?(socket_etc) do
      pubsub_subscribe(topic)
    else
      debug(topic, "LiveView is not connected so we skip subscribing to")
    end
  end

  def pubsub_subscribe(topic, socket) when not is_binary(topic) do
    with t when is_binary(t) <- maybe_to_string(topic) do
      debug(t, "transformed the topic into a string we can subscribe to")
      pubsub_subscribe(t, socket)
    else _ ->
      warn(topic, "could not transform the topic into a string we can subscribe to")
    end
  end

  defp pubsub_subscribe(topic) when is_binary(topic) and topic !="" do
    debug(topic, "subscribed")

    endpoint = Config.get(:endpoint_module, Bonfire.Web.Endpoint)

    # endpoint.unsubscribe(maybe_to_string(topic)) # to avoid duplicate subscriptions?
    endpoint.subscribe(topic)
    # Phoenix.PubSub.subscribe(Bonfire.PubSub, topic)
  end


  @doc """
  Broadcast some data for realtime updates, for example to a feed or thread
  """
  def pubsub_broadcast(topics, payload) when is_list(topics) do
    Enum.each(topics, &pubsub_broadcast(&1, payload))
  end

  def pubsub_broadcast(topic, {payload_type, _data} = payload) do
    debug("pubsub_broadcast: #{inspect topic} / #{inspect payload_type}")
    do_broadcast(topic, payload)
  end
  def pubsub_broadcast(topic, data)
  when (is_atom(topic) or is_binary(topic)) and topic !="" and not is_nil(data) do
    debug("pubsub_broadcast: #{inspect topic}")
    do_broadcast(topic, data)
  end
  def pubsub_broadcast(_, _), do: warn("pubsub did not broadcast")

  defp do_broadcast(topic, data) do
    # endpoint = Config.get(:endpoint_module, Bonfire.Web.Endpoint)
    # endpoint.broadcast_from(self(), topic, step, state)
    Phoenix.PubSub.broadcast(Bonfire.PubSub, maybe_to_string(topic), data)
  end


  def assigns_subscribe(%Phoenix.LiveView.Socket{} = socket, assign_names)
  when is_list(assign_names) or is_atom(assign_names) or is_binary(assign_names) do

    # subscribe to god-level assign + object ID based assign if ID provided in tuple
    names_of_assign_topics(assign_names)
    |> pubsub_subscribe(socket)

    socket
    |> self_subscribe(assign_names) # also subscribe to assigns for current user
  end

  @doc "Subscribe to assigns targeted at the current account/user"
  def self_subscribe(%Phoenix.LiveView.Socket{} = socket, assign_names)
  when is_list(assign_names) or is_atom(assign_names) or is_binary(assign_names) do
    target_ids = current_account_and_or_user_ids(socket)
    if is_list(target_ids) and target_ids != [] do
      target_ids
      |> names_of_assign_topics(assign_names)
      |> pubsub_subscribe(socket)
    else
      debug(target_ids, "cannot_self_subscribe")
    end
    socket
  end

  def cast_self(socket, assigns_to_broadcast) do
    assign_target_ids = current_account_and_or_user_ids(socket)

    if assign_target_ids do
      socket |> assign_and_broadcast(assigns_to_broadcast, assign_target_ids)
    else
      debug("cast_self: Cannot send via PubSub without an account and/or user in socket. Falling back to only setting an assign.")
      socket |> assign_global(assigns_to_broadcast)
    end
  end

  @doc "Warning: this will set assigns for any/all users who subscribe to them. You want to `cast_self/2` instead if dealing with user-specific actions or private data."
  def cast_public(socket, assigns_to_broadcast) do
    socket |> assign_and_broadcast(assigns_to_broadcast)
  end


  defp assign_and_broadcast(socket, assigns_to_broadcast, assign_target_ids \\ []) do
    assigns_broadcast(assigns_to_broadcast, assign_target_ids)
    socket |> assign_global(assigns_to_broadcast)
  end

  defp assigns_broadcast(assigns, assign_target_ids \\ [])
  defp assigns_broadcast(assigns, assign_target_ids) when is_list(assigns) do
    Enum.each(assigns, &assigns_broadcast(&1, assign_target_ids))
  end
  # defp assigns_broadcast({{assign_name, assign_id}, data}, assign_target_ids) do
  #   names_of_assign_topics([assign_id] ++ assign_target_ids, assign_name)
  #   |> pubsub_broadcast({:assign, {assign_name, data}})
  # end
  defp assigns_broadcast({assign_name, data}, assign_target_ids) do
    names_of_assign_topics(assign_target_ids, assign_name)
    |> pubsub_broadcast({:assign, {assign_name, data}})
  end


  defp names_of_assign_topics(assign_target_ids \\ [], assign_names)
  defp names_of_assign_topics(assign_target_ids, assign_names) when is_list(assign_names) do
    Enum.map(assign_names, &names_of_assign_topics(assign_target_ids, &1))
  end
  defp names_of_assign_topics(assign_target_ids, {assign_name, assign_id}) do
    names_of_assign_topics([assign_id] ++ assign_target_ids, assign_name)
  end
  defp names_of_assign_topics(assign_target_ids, assign_name) when is_list(assign_target_ids) and length(assign_target_ids)>0 do
    debug(assign_identified_object: {assign_name, assign_target_ids})
    [{:assign, assign_name}] ++ assign_target_ids
    |> Enum.map(&maybe_to_string/1)
    |> Enum.join(":")
  end
  defp names_of_assign_topics(_, assign_name) do
    debug(assign_god_level_object: {assign_name})
    {:assign, assign_name}
  end


  @doc """
  Run a function and expects tuple.
  If anything else is returned, like an error, a flash message is shown to the user.
  """
  def undead_mount(socket, fun), do: undead(socket, fun, {:mount, :ok})
  def undead_params(socket, fun), do: undead(socket, fun, {:mount, :noreply})

  def undead(socket, fun, return_key \\ :noreply) do
    fun.()
    # |> debug()
    |> undead_error(socket, return_key)
  rescue
    error in Ecto.Query.CastError ->
      live_exception(socket, return_key, "You seem to have provided an incorrect data type (eg. an invalid ID): ", error, __STACKTRACE__)
    error in Ecto.ConstraintError ->
      live_exception(socket, return_key, "You seem to be referencing an invalid object ID, or trying to insert duplicated data: ", error, __STACKTRACE__)
    error in FunctionClauseError ->
      # debug(error)
      with %{
        arity: arity,
        function: function,
        module: module
      } <- error do
        live_exception(socket, return_key, "The function #{function}/#{arity} in module #{module} didn't receive data in a format it can recognise: ", error, __STACKTRACE__)
      else error ->
        live_exception(socket, return_key, "A function didn't receive data in a format it could recognise: ", error, __STACKTRACE__)
      end
    error in WithClauseError ->
      live_exception(socket, return_key, "A `with` condition didn't receive data in a format it could recognise: ", term_error(error), __STACKTRACE__)
    error in CaseClauseError ->
      live_exception(socket, return_key, "A `case` condition didn't receive data in a format it could recognise: ", term_error(error), __STACKTRACE__)
    cs in Ecto.Changeset ->
        live_exception(socket, return_key, "The data provided caused an exceptional error and could do not be inserted or updated: "<>error_msg(cs), cs, nil)
    error ->
      live_exception(socket, return_key, "The app encountered an unexpected error: ", error, __STACKTRACE__)
  catch
    :exit, error ->
      live_exception(socket, return_key, "An exceptional error caused the operation to stop: ", error, __STACKTRACE__)
    :throw, {:error, error} when is_binary(error) ->
      live_exception(socket, return_key, error, nil, __STACKTRACE__)
    :throw, error ->
      live_exception(socket, return_key, "An exceptional error was thrown: ", error, __STACKTRACE__)
    error ->
      # error(error)
      live_exception(socket, return_key, "An exceptional error occured: ", error, __STACKTRACE__)
  end

  defp term_error(error) do
    with %{term: provided} <- error do
      error_msg(provided)
    else _ ->
      error
    end
  end

  def undead_error(error, socket, return_key \\ :noreply) do
   case error do
      {:ok, %Phoenix.LiveView.Socket{} = socket} -> {:ok, socket}
      {:ok, %Phoenix.LiveView.Socket{} = socket, data} -> {:ok, socket, data}
      {:noreply, %Phoenix.LiveView.Socket{} = socket} -> {:noreply, socket}
      {:noreply, %Plug.Conn{} = conn} -> {:noreply, conn}
      {:reply, data, %Phoenix.LiveView.Socket{} = socket} -> {:reply, data, socket}
      {:error, reason} -> undead_error(reason, socket, return_key)
      {:error, reason, extra} -> live_exception(socket, return_key, "There was an error: #{inspect reason}", extra)
      :ok -> {return_key, socket} # shortcut to return nothing
      {:ok, _other} -> {return_key, socket}
      %Ecto.Changeset{} = cs -> live_exception(socket, return_key, "The data provided seems invalid and could not be inserted or updated: "<>error_msg(cs), cs)
      %{__struct__: struct} = act when struct == Bonfire.Epics.Act -> live_exception(socket, return_key, "Could not complete this action: ", act)
      %{__struct__: struct} = epic when struct == Bonfire.Epics.Epic -> live_exception(socket, return_key, "Could not complete this request: "<>error_msg(epic), epic.errors)
      not_found when not_found in [:not_found, "Not found", 404] -> live_exception(socket, return_key, "Not found")
      msg when is_binary(msg) -> live_exception(socket, return_key, msg)
      ret -> live_exception(socket, return_key, "Oops, this resulted in something unexpected: ", ret)
    end
  end

  defp live_exception(socket, return_key, msg, exception \\ nil, stacktrace \\ nil, kind \\ :error)

  defp live_exception(socket, {:mount, return_key}, msg, exception, stacktrace, kind) do
    with {:error, msg} <- debug_exception(msg, exception, stacktrace, kind) do
      {return_key, socket
      |> assign_error(msg)
      |> redirect_to()
      }
    end
  end

  defp live_exception(%{assigns: %{__context__: %{current_url: current_url}}} = socket, return_key, msg, exception, stacktrace, kind) when is_binary(current_url) do
    with {:error, msg} <- debug_exception(msg, exception, stacktrace, kind) do
      {return_key, socket
      |> assign_error(msg)
      # |> patch_to(current_url)
      }
    end
  end

  defp live_exception(socket, return_key, msg, exception, stacktrace, kind) do
    with {:error, msg} <- debug_exception(msg, exception, stacktrace, kind) do
      {return_key, socket
      |> assign_error(msg)
      # |> patch_to(current_url(socket) || path(e(socket, :view, :error)))
      }
    end
  rescue
    FunctionClauseError -> # FIXME: handle cases where the live_path requires param(s)
      {return_key, socket
      |> assign_error(msg)
      |> redirect_to()
      }
  end

  def assign_error(socket, msg)  do
    assigns = %{error_sentry_event_id: maybe_last_sentry_event_id()}

    socket
      |> assign_generic(assigns)
      |> assign_flash(:error, error_msg(msg), assigns)
  end

  def maybe_last_sentry_event_id() do
    if module_enabled?(Sentry) do
      with {id, _source} when is_binary(id) <- Sentry.get_last_event_id_and_source() do
        id
      else _ ->
        nil
      end
    end
  end

  def redirect_to(socket_or_conn, to \\ nil, opts \\ [])
  def redirect_to(%Phoenix.LiveView.Socket{} = socket, to, opts) do
    Phoenix.LiveView.push_redirect(socket, [to: to || path_fallback(opts)] ++ opts)
  rescue e in ArgumentError ->
    error(e)
    redirect_to(socket, path_fallback(opts))
  end
  def redirect_to(%Plug.Conn{} = conn, to, opts) do
    Phoenix.Controller.redirect(conn, [to: to || path_fallback(opts)] ++ opts)
  end

  def patch_to(socket_or_conn, to \\ nil, opts \\ [])
  def patch_to(%Phoenix.LiveView.Socket{} = socket, to, opts) do
    Phoenix.LiveView.push_patch(socket, [to: to || path_fallback(opts)] ++ opts)
  rescue e in ArgumentError ->
    error(e)
    patch_to(socket, path_fallback(opts))
  end
  def patch_to(%Plug.Conn{} = conn, to, opts) do
    redirect_to(conn, to, opts)
  end

  def path_fallback(opts \\ []) do
    opts[:fallback] || path(:error) || "/error"
  end

  def assign_flash(socket_or_conn, type, message, assigns \\ %{})
  def assign_flash(%Phoenix.LiveView.Socket{} = socket, type, message, assigns) do
    info(message, type)
    Bonfire.UI.Common.Notifications.receive_flash(Map.put(assigns, type, message))
    Phoenix.LiveView.put_flash(socket, type, message)
  end
  def assign_flash(%Plug.Conn{} = conn, type, message, assigns) do
    info(message, type)
    # TODO: use assigns too
    conn
    |> Plug.Conn.fetch_session()
    |> Phoenix.Controller.fetch_flash()
    |> Phoenix.Controller.put_flash(type, message)
  end

  def maybe_consume_uploaded_entries(%Phoenix.LiveView.Socket{} = socket, key, fun) do
    Phoenix.LiveView.consume_uploaded_entries(socket, key, fun)
  rescue
    error in ArgumentError ->
      error(error, "Did not upload")
      []
  end

  def maybe_consume_uploaded_entries(_conn, key, _fun) do
    error(key, "Upload not currently implemented without LiveView")
    []
  end

  def maybe_consume_uploaded_entry(%Phoenix.LiveView.Socket{} = socket, key, fun) do
    Phoenix.LiveView.consume_uploaded_entry(socket, key, fun)
  end

  def maybe_consume_uploaded_entry(_conn, key, _fun) do
    error(key, "Upload not implemented without LiveView")
    nil
  end

  @doc "Save a `go` redirection path in the session (for redirecting somewhere after auth flows)"
  def set_go_after(conn, path \\ nil) do
    path = path || conn.request_path
    conn
    |> Plug.Conn.put_session(
      :go,
      path
    )
  end

  @doc """
  Generate a query string adding a `go` redirection path to the URI (for redirecting somewhere after auth flows).
  It is recommended to use `set_go_after/2` where possible instead.
  """
  def go_query(url) when is_binary(url), do: "?" <> Plug.Conn.Query.encode(go: url)
  def go_query(conn), do: "?" <> Plug.Conn.Query.encode(go: conn.request_path)

  @doc "copies the `go` param into a query string, if any"
  def copy_go(%{go: go}), do: "?" <> Plug.Conn.Query.encode(go: go)
  def copy_go(%{"go" => go}), do: "?" <> Plug.Conn.Query.encode(go: go)
  def copy_go(_), do: ""

  # TODO: we should validate this a bit harder. Phoenix will prevent
  # us from sending the user to an external URL, but it'll do so by
  # means of a 500 error.
  defp internal_go_path?("/" <> _), do: true
  defp internal_go_path?(_), do: false

  defp go_where?(session_go, %Ecto.Changeset{}=cs, default, current_path) do
    go_where?(session_go, cs.changes, default, current_path)
  end

  defp go_where?(session_go, params, default, current_path) do
    case session_go do
      go when is_binary(go) and current_path !=go ->
        if internal_go_path?(go), do: [to: go], else: [external: go] # needs to support external for oauth/openid
      _ ->
        go = (Utils.e(params, :go, nil) || default) #|> debug
        if current_path !=go and internal_go_path?(go), do: [to: go], else: [to: default]
    end
    |> debug()
  end

  def redirect_to_previous_go(conn, params, default, current_path) do
    # debug(conn.request_path)
    where = Plug.Conn.get_session(conn, :go)
    |> go_where?(params, default, current_path)

    conn
    |> Plug.Conn.delete_session(:go)
    |> Phoenix.Controller.redirect(where)
  end

  def maybe_cute_gif do
    num_gifs = 67 # TODO: detect
    dir = "data/uploads/cute-gifs/"
    if File.exists?(dir) do
      "/#{dir}#{Enum.random(1..num_gifs)}.gif"
    end
  end

  def hero_icons_list do
    with {:ok, list} <- :application.get_key(:surface_heroicons, :modules) do
      list
      |> Enum.filter(& &1 |> Module.split |> Enum.at(1) == "Solid")
      |> debug
      |> Enum.map(& {&1 |> Module.split |> Enum.at(2) |> to_string |> String.trim_trailing("Icon") |> Recase.to_sentence(), &1})
      |> Map.new()
      # |> Enum.reduce(user_data, fn m, acc -> apply(m, :create, acc) end)
    end
  end

  @message_types [:message, "message", :messages, "messages"]

  def is_messaging?(%{page: page}) when page in @message_types, do: true
  def is_messaging?(%{showing_within: showing_within}) when showing_within in @message_types, do: true
  def is_messaging?(%{create_activity_type: create_activity_type}) when create_activity_type in @message_types, do: true
  def is_messaging?(_), do: false

  def boundaries_or_default(to_boundaries, _opts) when is_list(to_boundaries) and length(to_boundaries)>0 do
    to_boundaries
  end
  def boundaries_or_default(_, opts) do
    default_boundaries(opts)
  end

  def default_boundaries(_opts \\ []) do
    # default boundaries for new stuff
    # TODO: make default user-configurable
    [{"public", l("Public")}]
  end

end
