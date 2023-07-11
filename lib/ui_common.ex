defmodule Bonfire.UI.Common do
  @moduledoc """
  A library of common utils and helpers used across Bonfire extensions
  """
  use Bonfire.Common.Utils
  use Untangle
  alias Bonfire.Common.PubSub

  defmacro __using__(_opts) do
    # TODO: pass opts to the nested `use`
    quote do
      use Bonfire.Common.Utils
      use Untangle
      import Bonfire.UI.Common
      alias Bonfire.Common.PubSub
    end
  end

  def assign_generic(socket_or_conn, {:error, error}) do
    assign_error(socket_or_conn, error)
  end

  def assign_generic(%Phoenix.LiveView.Socket{} = socket, assigns) do
    Phoenix.Component.assign(socket, assigns)
  end

  def assign_generic(%Plug.Conn{} = conn, assigns) do
    Plug.Conn.merge_assigns(conn, maybe_to_keyword_list(assigns, false))
  end

  def assign_generic(%{} = map, assigns) do
    Map.merge(map, Map.new(assigns))
  end

  def assign_generic({:ok, something}, assigns) do
    assign_generic(something, assigns)
  end

  def assign_generic(other, assigns) do
    warn(other, "Expected a Socket or Conn, got")
    Map.new(assigns)
  end

  def assign_generic(%Phoenix.LiveView.Socket{} = socket, key, value) do
    Phoenix.Component.assign(socket, key, value)
  end

  def assign_generic(%Plug.Conn{} = conn, key, value) do
    Plug.Conn.assign(conn, key, value)
  end

  def assign_generic(%{} = map, key, value) do
    Map.put(map, key, value)
  end

  def assign_generic(_, key, value) do
    %{} |> Map.put(key, value)
  end

  def assign_global(socket, assigns) when is_map(assigns) do
    # need this so any non-atom keys are turned into atoms
    Enums.input_to_atoms(assigns, true, false)
    |> Keyword.new()
    |> assign_global(socket, ...)
  end

  def assign_global(
        %{view: view, assigns: %{live_handler_via_module: component_or_view}} = socket,
        assigns
      )
      when is_list(assigns) and view != component_or_view do
    debug(
      component_or_view,
      "since we're assigning globally via a stateful component, send the assigns to parent view"
    )

    send_self_global(socket, assigns)
  end

  def assign_global(socket, assigns) when is_list(assigns) do
    socket
    # also put in non-context assigns
    |> assign_generic(assigns)
    |> Surface.Components.Context.put(assigns)

    # |> debug("put in context")
  end

  def assign_global(socket, {_, _} = assign) do
    assign_global(socket, Keyword.new([assign]))
  end

  def assign_global(socket, key, "") do
    assign_global(socket, key, nil)
  end

  def assign_global(socket, key, value) when is_atom(key) do
    assign_global(socket, {key, value})
  end

  def assign_global(socket, key, value) when is_binary(key) do
    case maybe_to_atom(key) do
      key when is_atom(key) ->
        assign_global(socket, {key, value})

      _ ->
        warn(key, "Could not assign (key is not an existing atom)")
        socket
    end
  end

  # def assign_global(socket, assign, value) do
  #   socket
  #   |> assign_generic(assign, value)
  #   |> assign_generic(:global_assigns, [assign] ++ Map.get(socket.assigns, :global_assigns, []))
  # end

  # TODO: get rid of assigning everything to a component, and then we'll no longer need this
  # def assigns_clean(%{} = assigns) when is_map(assigns), do: assigns_clean(Map.to_list(assigns))
  def assigns_clean({_, _} = tuple), do: assigns_clean([tuple])

  def assigns_clean(assigns) do
    # ++ [{:current_user, current_user(assigns)}]

    # temp workaround
    # |> IO.inspect
    Enum.reject(assigns, fn
      {key, _}
      when key in [
             # :__context__,
             :id,
             :flash,
             :__changed__,
             :__surface__,
             :socket,
             :myself
           ] ->
        true

      _ ->
        false
    end)

    # |> IO.inspect
  end

  def assigns_minimal(%{} = assigns) when is_map(assigns),
    do: assigns_minimal(Map.to_list(assigns))

  def assigns_minimal(assigns) do
    # |> IO.inspect
    preserve_global_assigns = Keyword.get(assigns, :global_assigns, []) || []

    # |> IO.inspect
    Enum.reject(assigns, fn
      {:current_user, _} -> false
      {:current_account, _} -> false
      {:global_assigns, _} -> false
      {assign, _} -> assign not in preserve_global_assigns
      _ -> true
    end)

    # |> IO.inspect
  end

  @decorate time()
  def assigns_merge(socket, assigns, new)

  def assigns_merge(%Phoenix.LiveView.Socket{} = socket, assigns, new)
      when is_map(assigns) or is_list(assigns),
      do: assign_generic(socket, assigns_merge(assigns, new))

  def assigns_merge(assigns, new) when is_map(assigns),
    do: assigns_merge(Map.to_list(assigns), new)

  def assigns_merge(assigns, new) when is_map(new),
    do: assigns_merge(assigns, Map.to_list(new))

  def assigns_merge(assigns, new) when is_list(assigns) and is_list(new) do
    assigns
    |> assigns_clean()
    |> deep_merge(new)

    # |> IO.inspect
  end

  def maybe_assign(socket, key, value)
      when is_atom(key) and not is_nil(value) and value != "" do
    assign_generic(socket, key, value)
  end

  def maybe_assign(socket, key, value)
      when is_binary(key) and key != "" and not is_nil(value) and value != "" do
    maybe_assign(socket, maybe_to_atom!(key), value)
  end

  def maybe_assign(socket, _key, _) do
    socket
  end

  def rich(content, opts \\ []) do
    case content do
      _ when is_binary(content) ->
        if opts[:skip_markdown] do
          content
        else
          # debug("use MD")

          content
          |> Text.maybe_markdown_to_html(Keyword.drop(opts, [:skip_markdown]))
        end
        # |> debug(content)
        # transform internal links to use LiveView navigation
        |> Text.make_local_links_live()
        # for use in views
        |> Phoenix.HTML.raw()

      {:ok, msg} when is_binary(msg) ->
        msg

      {:ok, _} ->
        debug(content)
        l("Ok")

      {:error, msg} when is_binary(msg) ->
        error(msg)
        msg

      {:error, _} ->
        error(content)
        l("Error")

      _ when is_map(content) ->
        error(content, "Unexpected data")
        l("Unexpected data")

      _ when is_nil(content) or content == "" ->
        nil

      %Ecto.Association.NotLoaded{} ->
        nil

      _ ->
        inspect(content)
    end
  end

  def markdown(content) when is_binary(content) do
    content
    # |> Text.maybe_markdown_to_html()
    |> rich()
  end

  def markdown(content) do
    rich(content)
  end

  def templated(content, data \\ %{})

  def templated(content, data) when is_binary(content) do
    content
    |> Text.maybe_render_templated(data)
    |> debug(content)
    |> Text.maybe_markdown_to_html()
    |> debug()
    |> rich()
  end

  def templated(content, _data) do
    rich(content)
  end

  def templated_or_remote_markdown(content, data \\ nil) do
    content = to_string(content)
    # debug(content)

    if Bonfire.Common.URIs.is_uri?(content) do
      with {:ok, %{body: body}} when is_binary(body) <-
             Bonfire.Common.HTTP.get_cached(content) do
        templated(body, data)
      else
        e ->
          debug(e, "Could not fetch remote content")
          templated(content, data)
      end
    else
      templated(content, data)
    end
  end

  def current_url(socket_or_assigns, default \\ nil) do
    case socket_or_assigns do
      %{current_url: url} when is_binary(url) ->
        url

      %{context: context} = _api_opts ->
        current_url(context, default)

      %{__context__: context} = _assigns ->
        current_url(context, default)

      %{assigns: assigns} = _socket ->
        current_url(assigns, default)

      %{socket: socket} = _socket ->
        current_url(socket, default)

      url when is_binary(url) ->
        url

      options when is_list(options) ->
        current_url(Map.new(options), default)

      other ->
        debug("No current_url found in #{inspect(other)}")
        default
    end
  end

  def current_user_or_remote_interaction(socket, verb, object) do
    case current_user(socket) do
      %{id: _} = current_user ->
        {:ok, current_user}

      _ ->
        redirect_to(
          socket,
          "/remote_interaction?type=#{verb}&name=#{e(object, :post_content, :name, nil) || e(object, :name, nil)}&url=#{canonical_url(object)}"
        )
    end
  end

  # defdelegate content(conn, name, type, opts \\ [do: ""]), to: Bonfire.PublisherThesis.ContentAreas

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

  def maybe_send_update(pid \\ self(), component, id, assigns)

  def maybe_send_update(pid, component, id, {:error, error})
      when is_atom(component) and not is_nil(id) do
    assign_error(nil, error, pid)
  end

  def maybe_send_update(pid, component, id, assigns)
      when is_atom(component) and not is_nil(id) do
    # Phoenix.LiveView.Channel.ping(self())

    # GenServer.call(Phoenix.LiveView.Channel, :ping)
    # |> debug()
    # :sys.get_state(pid)

    # Process.get()
    # |> debug()

    assigns = assigns_clean(assigns)

    debug(assigns, "Try sending to #{component} with id: #{id}")

    Phoenix.LiveView.send_update(
      pid || self(),
      component,
      Enum.into(assigns, %{id: id})
    )
  end

  def assigns_subscribe(%Phoenix.LiveView.Socket{} = socket, assign_names)
      when is_list(assign_names) or is_atom(assign_names) or
             is_binary(assign_names) do
    # subscribe to god-level assign + object ID based assign if ID provided in tuple
    names_of_assign_topics(assign_names)
    |> PubSub.subscribe(socket)

    # also subscribe to assigns for current user
    self_subscribe(
      socket,
      assign_names
    )
  end

  @doc "Subscribe to assigns targeted at the current account/user"
  def self_subscribe(%Phoenix.LiveView.Socket{} = socket, assign_names)
      when is_list(assign_names) or is_atom(assign_names) or
             is_binary(assign_names) do
    target_ids = current_account_and_or_user_ids(socket)

    if is_list(target_ids) and target_ids != [] do
      target_ids
      |> names_of_assign_topics(assign_names)
      |> PubSub.subscribe(socket)
    else
      debug(target_ids, "cannot_self_subscribe")
    end

    socket
  end

  def cast_self(socket, assigns_to_broadcast) do
    assign_target_ids = current_account_and_or_user_ids(socket)

    if assign_target_ids do
      assign_and_broadcast(socket, assigns_to_broadcast, assign_target_ids)
    else
      debug(
        "cast_self: Cannot send via PubSub without an account and/or user in socket. Falling back to setting an assign in the current view and component."
      )

      send_self(socket, assigns_to_broadcast)
    end
  end

  def send_self(socket \\ nil, assigns) do
    assigns = assigns_clean(assigns)
    send(self(), {:assign, assigns})
    if not is_nil(socket), do: assign_generic(socket, assigns)
  end

  def send_self_global(socket \\ nil, assigns) do
    assigns = assigns_clean(assigns)
    send(self(), {:assign_global, assigns})

    if not is_nil(socket),
      do:
        socket
        |> assign_generic(assigns)
        |> Surface.Components.Context.put(assigns)
  end

  @doc "Warning: this will set assigns for any/all users who subscribe to them. You want to `cast_self/2` instead if dealing with user-specific actions or private data."
  def cast_public(socket, assigns_to_broadcast) do
    assign_and_broadcast(socket, assigns_to_broadcast)
  end

  defp assign_and_broadcast(
         socket,
         assigns_to_broadcast,
         assign_target_ids \\ []
       ) do
    assigns_broadcast(assigns_to_broadcast, assign_target_ids)
    assign_generic(socket, assigns_to_broadcast)
  end

  defp assigns_broadcast(assigns, assign_target_ids)

  defp assigns_broadcast(assigns, assign_target_ids) when is_list(assigns) do
    assigns_clean(assigns)
    |> Enum.each(&assigns_broadcast(&1, assign_target_ids))
  end

  # defp assigns_broadcast({{assign_name, assign_id}, data}, assign_target_ids) do
  #   names_of_assign_topics([assign_id] ++ assign_target_ids, assign_name)
  #   |> PubSub.broadcast({:assign, {assign_name, data}})
  # end
  defp assigns_broadcast({assign_name, data}, assign_target_ids) do
    names_of_assign_topics(assign_target_ids, assign_name)
    |> PubSub.broadcast({:assign, {assign_name, assigns_clean(data)}})
  end

  defp names_of_assign_topics(assign_target_ids \\ [], assign_names)

  defp names_of_assign_topics(assign_target_ids, assign_names)
       when is_list(assign_names) do
    Enum.map(assign_names, &names_of_assign_topics(assign_target_ids, &1))
  end

  defp names_of_assign_topics(assign_target_ids, {assign_name, assign_id}) do
    names_of_assign_topics([assign_id] ++ assign_target_ids, assign_name)
  end

  defp names_of_assign_topics(assign_target_ids, assign_name)
       when is_list(assign_target_ids) and length(assign_target_ids) > 0 do
    debug(assign_identified_object: {assign_name, assign_target_ids})

    ([{:assign, assign_name}] ++ assign_target_ids)
    |> Enum.map(&maybe_to_string/1)
    |> Enum.join(":")
  end

  defp names_of_assign_topics(_, assign_name) do
    debug(assign_god_level_object: {assign_name})
    {:assign, assign_name}
  end

  defp db_error,
    do:
      l(
        "Sorry, the data provided has missing fields or is invalid and could do not be inserted or updated"
      )

  @doc """
  Run a function and expects tuple.
  If anything else is returned, like an error, a flash message is shown to the user.
  """
  def undead_mount(socket, fun), do: undead(socket, fun, {:mount, :ok})
  def undead_on_mount(socket, fun), do: undead(socket, fun, {:mount, :halt})
  def undead_params(socket, fun), do: undead(socket, fun, {:mount, :noreply})

  def undead(socket, fun, return_key \\ :noreply) do
    # |> debug()
    undead_maybe_handle_error(fun.(), socket, return_key)
  rescue
    msg in Bonfire.Fail.Auth ->
      go_login(msg, socket, return_key)

    msg in Bonfire.Fail ->
      case msg do
        %{code: :needs_login} ->
          go_login(msg, socket, return_key)

        _ ->
          live_exception(
            socket,
            return_key,
            msg,
            nil,
            __STACKTRACE__
          )
      end

    Pointers.NotFound ->
      live_exception(
        socket,
        return_key,
        l("Not found"),
        nil,
        __STACKTRACE__
      )

    error in Ecto.Query.CastError ->
      live_exception(
        socket,
        return_key,
        l("Sorry, the app tried to use an invalid data type"),
        error,
        __STACKTRACE__
      )

    error in Ecto.ConstraintError ->
      live_exception(
        socket,
        return_key,
        l("Sorry, the app tried to reference an invalid identifier or create a duplicate one"),
        error,
        __STACKTRACE__
      )

    error in DBConnection.ConnectionError ->
      live_exception(
        socket,
        return_key,
        "Sorry, could not connect to the database. Please try again later and/or contact the instance operators.",
        error,
        __STACKTRACE__
      )

    cs in Ecto.Changeset ->
      live_exception(
        socket,
        return_key,
        db_error() <> ": #{Errors.error_msg(cs)}",
        cs,
        nil
      )

    error in FunctionClauseError ->
      # debug(error)
      with %{
             arity: arity,
             function: function,
             module: module
           } <- error do
        live_exception(
          socket,
          return_key,
          l(
            "Sorry, the function %{function_name} in module %{module_name} didn't receive the data it was expecting",
            function_name: "`#{function}/#{arity}`",
            module_name: "`#{module}`"
          ),
          error,
          __STACKTRACE__
        )
      else
        error ->
          live_exception(
            socket,
            return_key,
            l("Sorry, a function didn't receive the data it was expecting"),
            error,
            __STACKTRACE__
          )
      end

    error in WithClauseError ->
      term_error(
        l("Sorry, a condition didn't match `with` any of the data it was expecting"),
        socket,
        return_key,
        error,
        __STACKTRACE__
      )

    error in CaseClauseError ->
      term_error(
        l("Sorry, a condition didn't have any `case` matching the data it was expecting"),
        socket,
        return_key,
        error,
        __STACKTRACE__
      )

    error in MatchError ->
      term_error(
        l("Sorry, a condition didn't receive data that matched a format it could recognise"),
        socket,
        return_key,
        error,
        __STACKTRACE__
      )

    error ->
      live_exception(
        socket,
        return_key,
        l("Sorry, the app encountered an unexpected error"),
        error,
        __STACKTRACE__
      )
  catch
    :exit, {:error, error} when is_binary(error) ->
      live_exception(socket, return_key, error, nil, __STACKTRACE__)

    :exit, error ->
      live_exception(
        socket,
        return_key,
        l("Sorry, an operation encountered an error and stopped"),
        error,
        __STACKTRACE__
      )

    :throw, {:error, error} when is_binary(error) ->
      live_exception(socket, return_key, error, nil, __STACKTRACE__)

    error ->
      # error(error)
      live_exception(
        socket,
        return_key,
        l("An exceptional error occurred"),
        error,
        __STACKTRACE__
      )
  end

  defp go_login(msg, socket, {_, return_key}), do: go_login(msg, socket, return_key)

  defp go_login(msg, socket, return_key) do
    {return_key,
     socket
     |> assign_error(e(msg, :message, l("You need to log in first.")))
     |> redirect_to("/login")}
  end

  defp term_error(
         _msg,
         socket,
         return_key,
         %{term: {:error, :not_found}},
         stacktrace
       ) do
    live_exception(socket, return_key, l("Not found"), nil, stacktrace)
  end

  defp term_error(msg, socket, return_key, error, stacktrace) do
    live_exception(socket, return_key, msg, term_error(error), stacktrace)
  end

  defp term_error(error) do
    with %{term: provided} <- error do
      Errors.error_msg(provided)
    else
      _ ->
        error
    end
  end

  defp undead_maybe_handle_error(error, socket, return_key) do
    case error do
      {:ok, %Phoenix.LiveView.Socket{} = socket} ->
        {:ok, socket}

      {:ok, %Phoenix.LiveView.Socket{} = socket, data} ->
        {:ok, socket, data}

      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      {:cont, %Phoenix.LiveView.Socket{} = socket} ->
        {:cont, socket}

      {:halt, %Phoenix.LiveView.Socket{} = socket} ->
        {:halt, socket}

      %Phoenix.LiveView.Socket{} = socket ->
        {return_key, socket}

      {:noreply, %Plug.Conn{} = conn} ->
        {:noreply, conn}

      %Plug.Conn{} = conn ->
        {return_key, conn}

      {:reply, data, %Phoenix.LiveView.Socket{} = socket} ->
        {:reply, data, socket}

      {:ok, {:error, reason}} ->
        undead_maybe_handle_error(reason, socket, return_key)

      {:noreply, {:error, reason}} ->
        undead_maybe_handle_error(reason, socket, return_key)

      {:error, reason} ->
        undead_maybe_handle_error(reason, socket, return_key)

      {:error, reason, extra} ->
        live_exception(
          socket,
          return_key,
          l("There was an error") <> ": #{inspect(reason)}",
          extra
        )

      # shortcut to return nothing
      :ok ->
        {return_key, socket}

      {:ok, _other} ->
        {return_key, socket}

      %Ecto.Changeset{} = cs ->
        live_exception(
          socket,
          return_key,
          db_error() <> ": #{Errors.error_msg(cs)}",
          cs
        )

      %Ecto.ConstraintError{} = cs ->
        live_exception(
          socket,
          return_key,
          db_error() <> ": #{Errors.error_msg(cs)}",
          nil
        )

      %{__struct__: struct} = act when struct == Bonfire.Epics.Act ->
        live_exception(
          socket,
          return_key,
          l("Sorry, an action could not be completed"),
          act
        )

      %{__struct__: struct} = epic when struct == Bonfire.Epics.Epic ->
        live_exception(
          socket,
          return_key,
          l("Sorry, a series of actions could not be completed") <> ": #{Errors.error_msg(epic)}",
          epic.errors,
          e(List.first(epic.errors), :stacktrace, nil)
        )

      not_found when not_found in [:not_found, "Not found", 404] ->
        live_exception(socket, return_key, l("Not found"))

      msg when is_binary(msg) ->
        live_exception(socket, return_key, msg)

      ret ->
        live_exception(
          socket,
          return_key,
          l("Sorry, this resulted in something unexpected"),
          ret
        )
    end
  end

  defp live_exception(
         socket,
         return_key,
         msg,
         exception \\ nil,
         stacktrace \\ nil,
         kind \\ :error
       )

  defp live_exception(
         socket,
         {:mount, return_key},
         msg,
         exception,
         stacktrace,
         kind
       ) do
    with {:error, msg} <-
           Errors.debug_exception(msg, exception, stacktrace, kind, as_markdown: true) do
      {return_key,
       socket
       |> assign_error(msg)
       |> redirect_to("/error")}
    end
  end

  # defp live_exception(
  #        %{assigns: %{__context__: %{current_url: current_url}}} = socket,
  #        return_key,
  #        msg,
  #        exception,
  #        stacktrace,
  #        kind
  #      ) when is_binary(current_url) do
  #   with {:error, msg} <-
  #          Errors.debug_exception(msg, exception, stacktrace, kind, as_markdown: true) do
  #     {
  #       return_key,
  #       assign_error(
  #         socket,
  #         msg
  #       )
  #       |> patch_to(current_url)
  #     }
  #   end
  # end

  defp live_exception(socket, return_key, msg, exception, stacktrace, kind) do
    with {:error, msg} <-
           Errors.debug_exception(msg, exception, stacktrace, kind, as_markdown: true) do
      {
        return_key,
        assign_error(
          socket,
          msg
        )
        # |> patch_to(current_url(socket) || path(e(socket, :view, :error)))
      }
    end
  rescue
    # FIXME: handle cases where the live_path requires param(s)
    FunctionClauseError ->
      {return_key,
       socket
       |> assign_error(msg)
       |> redirect_to("/error")}
  end

  def maybe_last_sentry_event_id() do
    if module_enabled?(Sentry) do
      with {id, _source} when is_binary(id) <-
             Sentry.get_last_event_id_and_source() do
        id
      else
        _ ->
          nil
      end
    end
  end

  def redirect_to(socket_or_conn, to \\ nil, opts \\ [])

  def redirect_to(%Phoenix.LiveView.Socket{} = socket, to, opts) do
    Phoenix.LiveView.push_navigate(
      socket,
      [to: to || path_fallback(socket, opts)] ++ opts
    )
  rescue
    e in ArgumentError ->
      error(e)
      redirect_to(socket, path_fallback(socket, opts))
  end

  def redirect_to(%Plug.Conn{} = conn, to, opts) do
    Phoenix.Controller.redirect(
      conn,
      [to: to || path_fallback(conn, opts)] ++ opts
    )
  end

  def patch_to(socket_or_conn, to \\ nil, opts \\ [])

  def patch_to(socket_or_conn, %URI{path: path}, opts) do
    patch_to(socket_or_conn, path, opts)
  end

  def patch_to(%Phoenix.LiveView.Socket{} = socket, to, opts) when is_binary(to) do
    Phoenix.LiveView.push_patch(
      socket,
      [to: to] ++ opts
    )
  rescue
    e in ArgumentError ->
      error(e)
      patch_to(socket, path_fallback(socket, opts))
  end

  def patch_to(%Phoenix.LiveView.Socket{} = socket, _, opts) do
    patch_to(socket, path_fallback(socket, opts))
  end

  def patch_to(%Plug.Conn{} = conn, to, opts) do
    redirect_to(conn, to, opts)
  end

  def path_fallback(socket_or_conn, opts) do
    opts[:fallback] || current_url(socket_or_conn) || path(:error) || "/error"
  end

  def maybe_push_event(%Phoenix.LiveView.Socket{} = socket, name, data) do
    debug(data, name)

    Phoenix.LiveView.push_event(socket, name, data)
  end

  def maybe_push_event(conn, name, _data) do
    debug(name, "No socket, so could not push_event")
    conn
  end

  def assign_flash(socket_or_conn, type, message, assigns \\ %{}, pid \\ self())

  def assign_flash(%Phoenix.LiveView.Socket{} = socket, type, message, assigns, pid) do
    # info(message, type)

    if socket_connected?(socket) do
      Bonfire.UI.Common.Notifications.receive_flash(
        Map.put(assigns, type, message),
        pid,
        socket.assigns[:__context__]
      )

      Phoenix.LiveView.put_flash(socket, type, message)
    else
      # for non-live
      Phoenix.LiveView.put_flash(socket, type, string_for_cookie(message))
    end
  end

  def assign_flash(%Plug.Conn{} = conn, type, message, assigns, _pid) do
    # info(message, type)

    conn
    |> Plug.Conn.fetch_session()
    |> Phoenix.Controller.fetch_flash()
    |> Phoenix.Controller.put_flash(type, string_for_cookie(message))
    |> assign_generic(assigns)
  end

  def assign_flash(other, type, message, assigns, pid) do
    warn(other, "Expected a conn or socket")

    Bonfire.UI.Common.Notifications.receive_flash(Map.put(assigns, type, message), pid)

    other
  end

  defp string_for_cookie(message) when byte_size(message) > 2000,
    do: binary_part(message, 0, 2000)

  defp string_for_cookie(message), do: message

  def assign_error(socket, msg, pid \\ self()) do
    assigns = %{error_sentry_event_id: maybe_last_sentry_event_id()}

    socket
    |> assign_generic(assigns)
    |> assign_flash(:error, Errors.error_msg(msg), assigns, pid)
  end

  def live_upload_files(current_user, metadata, socket) do
    maybe_consume_uploaded_entries(socket, :files, fn %{path: path} = _meta, entry ->
      # debug(meta, "consume_uploaded_entries meta")
      # debug(entry, "consume_uploaded_entries entry")

      with {:ok, uploaded} <-
             Bonfire.Files.upload(nil, current_user, path, %{
               client_name: entry.client_name,
               metadata: metadata[entry.ref]
             })
             |> debug("uploaded") do
        {:ok, uploaded}
      else
        e ->
          error(e, "Did not upload #{entry.client_name}")
          {:postpone, nil}
      end
    end)
    |> filter_empty([])
  end

  def maybe_consume_uploaded_entries(
        %Phoenix.LiveView.Socket{} = socket,
        key,
        fun
      ) do
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

  def maybe_consume_uploaded_entry(
        %Phoenix.LiveView.Socket{} = socket,
        key,
        fun
      ) do
    Phoenix.LiveView.consume_uploaded_entry(socket, key, fun)
  rescue
    error in ArgumentError ->
      error(error, "Did not upload")
  end

  def maybe_consume_uploaded_entry(_conn, key, _fun) do
    error(key, "Upload not implemented without LiveView")
    nil
  end

  @doc "Save a `go` redirection path in the session (for redirecting somewhere after auth flows)"
  def set_go_after(conn, path \\ nil) do
    path = path || conn.request_path

    Plug.Conn.put_session(
      conn,
      :go,
      path
    )
  end

  @doc """
  Generate a query string adding a `go` redirection path to the URI (for redirecting somewhere after auth flows).
  It is recommended to use `set_go_after/2` where possible instead.
  """
  def go_query(url) when is_binary(url),
    do: "?" <> Plug.Conn.Query.encode(go: url)

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

  defp go_where?(session_go, %Ecto.Changeset{} = cs, default, current_path) do
    go_where?(session_go, cs.changes, default, current_path)
  end

  defp go_where?(session_go, params, default, current_path) do
    case session_go do
      go when is_binary(go) and current_path != go ->
        go = URI.decode(go)
        # needs to support external for oauth/openid
        if internal_go_path?(go), do: [to: go], else: [external: go]

      _ ->
        # |> debug
        go = (Utils.e(params, :go, nil) || default) |> URI.decode()

        if current_path != go and internal_go_path?(go),
          do: [to: go],
          else: [to: default]
    end
    |> debug()
  end

  def redirect_to_previous_go(conn, params, default, current_path) do
    # debug(conn.request_path)
    where =
      Plug.Conn.get_session(conn, :go)
      |> go_where?(params, default, current_path)

    conn
    |> Plug.Conn.delete_session(:go)
    |> Phoenix.Controller.redirect(where)
  end

  def maybe_cute_gif do
    # TODO: detect
    num_gifs = 67
    dir = "data/uploads/cute-gifs/"

    if File.exists?(dir) do
      "/#{dir}#{Enum.random(1..num_gifs)}.gif"
    end
  end

  def hero_icons_list do
    with {:ok, list} <- :application.get_key(:surface_heroicons, :modules) do
      list
      |> Enum.filter(&(&1 |> Module.split() |> Enum.at(1) == "Solid"))
      |> debug()
      |> Enum.map(
        &{&1
         |> Module.split()
         |> Enum.at(2)
         |> to_string()
         |> String.trim_trailing("Icon")
         |> Recase.to_sentence(), &1}
      )
      |> Map.new()

      # |> Enum.reduce(user_data, fn m, acc -> apply(m, :create, acc) end)
    end
  end

  def boundaries_or_default(to_boundaries, opts \\ [])

  def boundaries_or_default(to_boundaries, _opts)
      when is_list(to_boundaries) and length(to_boundaries) > 0 do
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

  def the_object(assigns) do
    e(assigns, :object, nil) || e(assigns, :activity, :object, nil) ||
      e(assigns, :object_id, nil) || e(assigns, :activity, :object_id, nil) ||
      e(assigns, :id, nil)
  end

  def preload_assigns_async(list_of_assigns, assigns_to_params_fn, preload_fn, opts \\ [])
      when is_list(list_of_assigns) and is_function(assigns_to_params_fn, 1) and
             is_function(preload_fn, 3) do
    connected? = socket_connected?(List.first(list_of_assigns))
    current_user = current_user(list_of_assigns)
    # |> info("current_user")

    list_of_components =
      list_of_assigns
      # |> debug("list of assigns")
      #  avoid re-preloading
      |> Enum.filter(
        &is_nil(
          Map.get(&1, opts[:skip_if_set] || opts[:preload_status_key] || :preloaded_async_assigns)
        )
      )
      # |> debug("process these assigns")
      |> Enum.map(&assigns_to_params_fn.(&1))

    # |> debug("list_of_components")

    if list_of_components == [] do
      list_of_assigns
    else
      list_of_ids =
        list_of_components
        |> Enum.map(fn %{object_id: object_id} ->
          object_id
        end)
        |> filter_empty([])
        |> Enum.uniq()

      # |> debug("list_of_ids")

      env = Config.env()

      if ((connected? == true and env != :test) or
            Process.get(:enable_async_preloads) == true) and
           not is_nil(opts[:caller_module]) do
        debug(preload_fn, "preloading using async :-)")
        pid = self()

        Task.start(fn ->
          preload_fn.(list_of_components, list_of_ids, current_user)
          |> Enum.each(fn {component_id, assigns} ->
            maybe_send_update(
              pid,
              opts[:caller_module],
              component_id,
              Map.put(assigns, opts[:preload_status_key] || :preloaded_async_assigns, true)
            )
          end)

          # send(pid, :preload_done)
        end)

        list_of_assigns
      else
        if env != :test and not is_nil(current_user) do
          debug(preload_fn, "wait to preload once socket is connected")
          list_of_assigns
        else
          debug(preload_fn, "preloading WITHOUT using async")

          preloaded_assigns = preload_fn.(list_of_components, list_of_ids, current_user)
          # |> debug("preloaded assigns for components")

          list_of_assigns
          |> Enum.map(fn %{id: component_id} = assigns ->
            assigns
            |> Map.merge(preloaded_assigns[component_id] || %{})
          end)
        end
      end
    end
  end

  @doc """
  Inserts onr or many items in an existing stream.
  See `Phoenix.LiveView.stream_insert/4` for opts.
  """
  def maybe_stream_insert(%{assigns: %{streams: _}} = socket, name, items, opts)
      when is_list(items) do
    Phoenix.LiveView.stream(socket, name, items, opts)
  end

  def maybe_stream_insert(%{assigns: %{streams: _}} = socket, name, item, opts) do
    Phoenix.LiveView.stream_insert(socket, name, item, opts)
  end

  def maybe_stream_insert(socket, name, items, _opts) do
    error(
      socket.assigns,
      "Could not find stream '#{name}' to render data in. Will set as regular assign instead"
    )

    socket
    |> assign_generic(name, items)
  end
end
