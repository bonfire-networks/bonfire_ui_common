defmodule Bonfire.UI.Common do
  @moduledoc """
  A library of common utils and helpers used across Bonfire extensions
  """
  use Bonfire.Common.Utils
  use Untangle
  alias Bonfire.Common.PubSub
  alias Bonfire.UI.Common.ErrorHandling

  declare_extension("Common UI components",
    icon: "fluent-mdl2:web-components",
    emoji: "🧩",
    description: l("Reusable user interface components and utilities.")
  )

  defmacro __using__(_opts) do
    # TODO: pass opts to the nested `use`
    quote do
      use Bonfire.Common.Utils
      use Untangle
      import Bonfire.UI.Common
      import Bonfire.UI.Common.Modularity.DeclareHelpers
      alias Bonfire.Common.PubSub
    end
  end

  def maybe_component(module, context \\ []) do
    case maybe_module(module, context) do
      nil ->
        warn(module, "Component module is disabled and no replacement was configured")
        Bonfire.UI.Common.DisabledModuleLive

      module ->
        module
    end
  end

  def maybe_apply_or_ret(assigns, mod, fun) when is_atom(fun) and not is_nil(fun),
    do:
      maybe_apply(mod, fun, [assigns], fn error, _details ->
        error(error)
        assigns
      end)

  def maybe_apply_or_ret(assigns, _, _), do: assigns

  defmacro render_sface_or_native(opts \\ []) do
    if extension_enabled?(:live_view_native) and Version.match?(System.version(), ">= 1.15.0") do
      quote do
        def render(%{format: :html} = assigns) do
          assigns
          |> maybe_apply_or_ret(__MODULE__, unquote(opts)[:prepare_assigns_fn])
          |> render_sface()
        end

        def render(%{format: _} = assigns) do
          assigns
          |> maybe_apply_or_ret(__MODULE__, unquote(opts)[:prepare_assigns_fn])
          |> render_native()
        end

        def render(assigns) do
          assigns
          |> maybe_apply_or_ret(__MODULE__, unquote(opts)[:prepare_assigns_fn])
          |> render_sface()
        end
      end
    else
      # fallback to only HTML for backwards compat with older Elixir versions
      quote do
        def render(assigns) do
          assigns
          |> maybe_apply_or_ret(__MODULE__, unquote(opts)[:prepare_assigns_fn])
          |> render_sface()
        end
      end
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

  def assign_generic_global(%Phoenix.LiveView.Socket{} = socket, assigns) do
    Surface.Components.Context.put(socket, assigns)
  end

  def assign_generic_global(%Plug.Conn{} = conn, assigns) do
    Plug.Conn.assign(
      conn,
      :__context__,
      Map.merge(conn.assigns[:__context__] || %{}, Map.new(assigns))
    )
  end

  def assign_global(socket, assigns) when is_map(assigns) do
    # need this so any non-atom keys are turned into atoms
    Enums.input_to_atoms(assigns,
      discard_unknown_keys: true,
      values: false,
      also_discard_unknown_nested_keys: false
    )
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
    |> assign_generic_global(assigns)

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
             #  :uploads,
             :__changed__,
             :__surface__,
             :socket,
             :myself
           ] ->
        true

      _ ->
        false
    end)
    |> debug()
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

  # TODO: caching
  def rich(content, opts \\ []) do
    case content do
      _ when is_binary(content) ->
        if opts[:skip_markdown] do
          content
        else
          # debug("use MD")

          content
          |> debug("to convert to markdown")
          |> Text.maybe_markdown_to_html(
            opts
            |> Keyword.drop([:skip_markdown])
          )
        end
        |> debug("rich content")
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

  # TODO: only render this once
  def templated(content, data \\ %{})

  def templated(content, data) when is_binary(content) and content != "" do
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

  def current_url(socket_or_assigns, default \\ nil, recursing \\ false) do
    case socket_or_assigns do
      %{current_url: url} when is_binary(url) ->
        url

      %{context: context} = _api_opts ->
        current_url(context, default, true)

      %{__context__: context} = _assigns ->
        current_url(context, default, true)

      %{assigns: assigns} = _socket ->
        current_url(assigns, default, true)

      %{socket: socket} = _socket ->
        current_url(socket, default, true)

      url when is_binary(url) ->
        url

      options when is_list(options) ->
        current_url(Map.new(options), default, true)

      _ ->
        nil
    end ||
      if(recursing == false,
        do:
          (
            debug(socket_or_assigns, "No current_url found in")
            default
          )
      )
  end

  def current_user_or_remote_interaction(socket, verb, object) do
    case current_user(socket.assigns) do
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

  def maybe_send_update(component, id, assigns, opts \\ [])

  def maybe_send_update(component, id, {:error, error}, opts) do
    assign_error(nil, error, opts[:pid])
  end

  def maybe_send_update(component, id, assigns, pid) when is_pid(pid) do
    maybe_send_update(component, id, assigns, pid: pid)
  end

  def maybe_send_update(component, ids, assigns, opts) when is_list(ids) do
    assigns =
      assigns_clean(assigns)
      |> debug("Try sending to #{component} with ids: #{inspect(ids)}")

    for id <- ids do
      do_send_update(opts[:pid], component, id, assigns)
    end
  end

  def maybe_send_update(component, id, assigns, opts)
      when is_atom(component) and not is_nil(id) do
    debug(assigns, "Try sending to #{component} with id: #{id}")

    do_send_update(
      opts[:pid],
      component,
      id,
      assigns_clean(assigns)
    )
  end

  def maybe_send_update(component, id, _assigns, _opts)
      when not is_nil(id) do
    error(component, "expected a component module but got")
  end

  def maybe_send_update(component, id, _assigns, _) do
    error(id, "expected a component ID but got")
  end

  defp do_send_update(pid, component, id, assigns)
       when is_atom(component) and not is_nil(id) do
    # Phoenix.LiveView.Channel.ping(self())

    # GenServer.call(Phoenix.LiveView.Channel, :ping)
    # |> debug()
    # :sys.get_state(pid)

    # Process.get()
    # |> debug()

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
        |> assign_generic_global(assigns)
  end

  def redirect_self(to) do
    send(self(), {:redirect, to})
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

  @doc """
  Run a function and expects tuple.
  If anything else is returned, like an error, a flash message is shown to the user.
  """
  def undead_mount(socket, fun), do: ErrorHandling.undead(socket, fun, {:mount, :ok})
  def undead_on_mount(socket, fun), do: ErrorHandling.undead(socket, fun, {:mount, :halt})
  def undead_update(socket, fun), do: ErrorHandling.undead(socket, fun, {:update, :ok})
  def undead_render(assigns, fun), do: ErrorHandling.undead(assigns, fun, {nil, :render})

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

  def redirect_to(socket, to, opts) when is_nil(to) or to == "" do
    redirect_to(socket, path_fallback(socket, opts), opts)
  end

  def redirect_to(%Phoenix.LiveView.Socket{redirected: nil} = socket, to, opts) do
    debug(to, "redirect socket to")
    debug(socket)

    Phoenix.LiveView.push_navigate(
      socket,
      [to: to || path_fallback(socket, opts)] ++ List.wrap(opts)
    )
  rescue
    e in ArgumentError ->
      path_fallback = path_fallback(socket, opts)
      error(e, "could not redirect")
      if path_fallback != to, do: redirect_to(socket, path_fallback), else: socket

    e in RuntimeError ->
      error(e, "could not redirect")
      socket
  end

  def redirect_to(%Phoenix.LiveView.Socket{redirected: already} = socket, to, _opts) do
    warn(to, "socket already prepared to redirect to #{inspect(already)}, so cannot redirect to")
    socket
  end

  def redirect_to(%Plug.Conn{} = conn, to, opts) do
    debug(to, "redirect plug to")

    Phoenix.Controller.redirect(
      conn,
      [to: to || path_fallback(conn, opts)] ++ List.wrap(opts)
    )
  end

  def patch_to(socket_or_conn, to \\ nil, opts \\ [])

  def patch_to(socket_or_conn, %URI{path: path}, opts) do
    patch_to(socket_or_conn, path, opts)
  end

  def patch_to(socket, to, opts) when is_nil(to) or to == "" do
    patch_to(socket, path_fallback(socket, opts), opts)
  end

  def patch_to(%Phoenix.LiveView.Socket{} = socket, to, opts) when is_binary(to) do
    debug(to, "patch socket to")

    Phoenix.LiveView.push_patch(
      socket,
      [to: to] ++ List.wrap(opts)
    )
  rescue
    e in ArgumentError ->
      error(e)
      patch_to(socket, path_fallback(socket, opts))
  end

  def patch_to(%Phoenix.LiveView.Socket{} = socket, _, opts) do
    patch_to(socket, path_fallback(socket, opts))
  end

  def patch_to(conn, to, opts) do
    redirect_to(conn, to, opts)
  end

  def path_fallback(socket_or_conn, opts) do
    opts[:fallback] || current_url(socket_or_conn) || "/error?invalid_path"
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

  def maybe_assign_context(socket, %{__context__: assigns}) do
    debug(assigns, "assign updated data with settings")

    socket
    |> assign_global(assigns)
  end

  def maybe_assign_context(socket, %{id: "3SERSFR0MY0VR10CA11NSTANCE", data: settings}) do
    debug(settings, "assign updated instance settings")

    socket
    |> assign_global(instance_settings: settings)
  end

  def maybe_assign_context(socket, ret) do
    debug(ret, "cannot assign updated data with settings")
    socket
  end

  defp string_for_cookie(message) when byte_size(message) > 2000,
    do: binary_part(message, 0, 2000)

  defp string_for_cookie(message), do: message

  def assign_error(socket, msg, pid \\ self())

  def assign_error(socket, code, pid) when is_atom(code) do
    if module_enabled?(Bonfire.Fail) do
      %{message: message} = Bonfire.Fail.fail(code)
      assign_error(socket, message, pid)
    else
      assign_error(socket, to_string(code), pid)
    end
  end

  def assign_error(socket, msg, pid) do
    assigns = %{error_sentry_event_id: maybe_last_sentry_event_id()}

    socket
    |> assign_generic(assigns)
    |> assign_flash(:error, Errors.error_msg(msg), assigns, pid)
  end

  def live_upload_files(module \\ nil, upload_field \\ :files, current_user, metadata, socket) do
    maybe_consume_uploaded_entries(socket, upload_field, fn %{path: path} = _meta, entry ->
      # debug(meta, "consume_uploaded_entries meta")
      # debug(entry, "consume_uploaded_entries entry")

      with {:ok, uploaded} <-
             Bonfire.Files.upload(
               module,
               current_user,
               path,
               %{
                 client_name: entry.client_name,
                 metadata: metadata[entry.ref] || metadata
               },
               move_original: true
             )
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
      info(__STACKTRACE__)
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
      info(__STACKTRACE__)
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
    opts = Config.get(:cute_gifs)

    if opts[:num] && opts[:num] > 0 do
      "/#{opts[:dir]}#{Enum.random(1..opts[:num])}.gif"
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

  def the_object(assigns) do
    e(assigns, :object, nil) || e(assigns, :activity, :object, nil) ||
      e(assigns, :object_id, nil) || e(assigns, :activity, :object_id, nil) ||
      e(assigns, :id, nil)
  end

  def update_many_async(assigns_sockets, opts) when is_list(assigns_sockets) do
    {current_user, opts} = opts_for_update_many_async(List.first(assigns_sockets), opts)
    update_many_async(current_user, assigns_sockets, opts)
  end

  def update_many_async(current_user, assigns_sockets, opts) when is_list(assigns_sockets) do
    case prepare_update_many_async(assigns_sockets, opts[:mode], opts) do
      nil ->
        #  skipped, return original sockets/assigns
        maybe_assign_provided(assigns_sockets, !opts[:return_assigns_socket_tuple])

      {:async, preload_status_key, preload_fn, list_of_ids, list_of_components}
      when is_function(preload_fn, 3) ->
        # actually do the preload async
        debug(preload_fn, "preloading using async :-)")
        pid = self()

        apply_task(:start_link, fn ->
          preload_fn.(list_of_components, list_of_ids, current_user)
          |> Enum.each(fn
            {component_id, %{} = assigns} ->
              # debug(assigns, "ahjkjhkh")

              maybe_send_update(
                opts[:caller_module],
                component_id,
                Map.put(assigns, preload_status_key, true),
                pid
              )

            other ->
              warn(other, "skip sending assigns")
          end)

          # send(pid, :preload_done)
        end)

        # while the async stuff is running, return the original assigns
        maybe_assign_provided(assigns_sockets, !opts[:return_assigns_socket_tuple])

      {:inline, preload_status_key, preload_fn, list_of_ids, list_of_components}
      when is_function(preload_fn, 3) ->
        #  return inline
        debug(preload_fn, "preloading inline")

        preloaded_assigns = preload_fn.(list_of_components, list_of_ids, current_user)

        # |> debug("preloaded assigns for components")

        assigns_sockets
        |> Enum.map(fn {%{id: component_id} = assigns, socket} ->
          socket
          |> maybe_assign_provided(
            assigns
            |> Map.merge(e(preloaded_assigns, component_id, %{}))
            |> Map.put(preload_status_key, true),
            !opts[:return_assigns_socket_tuple]
          )
        end)

      # return updated sockets/assigns
      assigns_sockets_or_sockets ->
        assigns_sockets_or_sockets
    end
  end

  def batch_update_many_async(assigns_sockets, many_opts, opts)
      when is_list(assigns_sockets) and is_list(many_opts) and is_list(opts) do
    {current_user, opts} = opts_for_update_many_async(List.first(assigns_sockets), opts)

    batch_update_many_async(current_user, assigns_sockets, many_opts, opts)
  end

  def batch_update_many_async(current_user, assigns_sockets, many_opts, opts)
      when is_list(assigns_sockets) and is_list(many_opts) and is_list(opts) do
    # while the async stuff is running, return the original assigns
    case Enum.map(many_opts, fn single_opts ->
           prepare_update_many_async(assigns_sockets, opts[:mode], single_opts)
         end) do
      nil ->
        nil

      [] ->
        nil

      prepared_groups ->
        prepared_groups =
          prepared_groups
          |> Enum.group_by(fn
            nil ->
              nil

            tuple when is_tuple(tuple) ->
              elem(tuple, 0)

            other ->
              error(other, "unexpected")
              nil
          end)
          |> debug("prepared_groups")

        case Map.get(prepared_groups, :async) do
          nil ->
            nil

          async_groups ->
            pid = self()

            apply_task(:start_link, fn ->
              {preload_status_keys, preloaded_assigns} =
                do_batch_preloads(async_groups, current_user)

              preloaded_assigns
              |> Enum.each(fn
                {component_id, %{} = assigns} ->
                  # debug(assigns, "ahjkjhkh")

                  maybe_send_update(
                    opts[:caller_module],
                    component_id,
                    Map.merge(assigns, preload_status_keys),
                    pid
                  )

                other ->
                  warn(other, "skip sending assigns")
              end)

              # end async ops
            end)

            nil
        end

        case Map.get(prepared_groups, :inline) do
          nil ->
            nil

          async_groups ->
            {preload_status_keys, preloaded_assigns} =
              do_batch_preloads(async_groups, current_user)

            assigns_sockets
            |> Enum.map(fn {%{id: component_id} = assigns, socket} ->
              socket
              |> maybe_assign_provided(
                assigns
                |> Map.merge(e(preloaded_assigns, component_id, %{}))
                |> Map.merge(preload_status_keys),
                !opts[:return_assigns_socket_tuple]
              )
            end)
        end
    end ||
      maybe_assign_provided(assigns_sockets, !opts[:return_assigns_socket_tuple])
  end

  defp do_batch_preloads(async_groups, current_user) do
    async_data =
      async_groups
      |> Enum.map(fn {_mode, preload_status_key, preload_fn, list_of_ids, list_of_components} ->
        # same as `Task.async/1` but supports multi-tenancy
        Utils.apply_task(:async, fn ->
          {preload_status_key, preload_fn.(list_of_components, list_of_ids, current_user)}
        end)
      end)
      # long timeout for now - TODO: configurable
      |> Task.await_many(5_000_000)
      |> debug("parallel done")

    preload_status_keys =
      Keyword.keys(async_data)
      |> debug("preload_status_keys")
      |> Map.new(fn preload_status_key -> {preload_status_key, true} end)
      |> debug()

    async_data =
      async_data
      |> Enum.reduce(%{}, fn {_preload_status_key, group_map}, acc ->
        acc
        |> Enums.deep_merge(group_map, replace_lists: true)

        # |> Map.merge(%{extra_assigns: %{^preload_status_key => true}})
      end)
      |> debug("merge done")

    {preload_status_keys, async_data}
  end

  def opts_for_update_many_async({assigns, socket}, opts) do
    env = Config.env()

    connected? = socket_connected?(socket)

    current_user =
      current_user(assigns) ||
        current_user(socket)

    live_update_many_preloads = opts[:live_update_many_preloads] || live_update_many_preloads?()

    mode =
      cond do
        live_update_many_preloads == :skip -> :wait
        live_update_many_preloads == :inline -> :inline
        connected? == true and env != :test and not is_nil(opts[:caller_module]) -> :async
        live_update_many_preloads == :user_async_or_skip -> :skip
        env != :test and not is_nil(current_user) -> :wait
        true -> :inline
      end

    {current_user,
     opts ++
       [
         mode: mode,
         showing_within:
           e(assigns, :showing_within, nil) ||
             e(socket, :assigns, :showing_within, nil)
       ]}
  end

  # @decorate time()
  defp prepare_update_many_async(assigns_sockets, mode, opts) do
    mode =
      cond do
        opts[:live_update_many_preloads] == :skip -> :wait
        opts[:live_update_many_preloads] == :inline -> :inline
        true -> mode
      end
      |> debug("mode")

    if mode in [:async, :inline] do
      with {:ok, preload_status_key, list_of_ids, list_of_components} <-
             prepare_components_for_update_many(
               assigns_sockets,
               opts[:assigns_to_params_fn],
               opts
             ) do
        {mode, preload_status_key, opts[:preload_fn], list_of_ids, list_of_components}
      end
    else
      debug("wait to preload once socket is connected")

      nil
    end
  end

  defp prepare_components_for_update_many(assigns_sockets, assigns_to_params_fn, opts)
       when is_function(assigns_to_params_fn, 1) do
    preload_status_key = opts[:preload_status_key] || :preloaded_async_assigns

    list_of_components =
      assigns_sockets
      # |> debug("list of assigns")
      #  avoid re-preloading
      |> Enum.filter(fn {assigns, _socket} ->
        is_nil(
          Map.get(
            assigns,
            opts[:skip_if_set] || preload_status_key
          )
        )
      end)
      # |> debug("process these assigns")
      |> Enum.map(fn {assigns, _socket} -> assigns_to_params_fn.(assigns) end)

    # |> debug("list_of_components")

    if list_of_components == [] do
      nil
    else
      list_of_ids =
        list_of_components
        |> Enum.map(fn %{object_id: object_id} ->
          object_id
        end)
        |> filter_empty([])
        |> Enum.uniq()

      {:ok, preload_status_key, list_of_ids, list_of_components}
    end
  end

  defp live_update_many_preloads?,
    do: Process.get(:live_update_many_preloads) || Config.get(:live_update_many_preloads)

  defp maybe_assign_provided(assigns_sockets, false), do: assigns_sockets

  defp maybe_assign_provided(assigns_sockets, _true) when is_list(assigns_sockets) do
    assigns_sockets
    |> Enum.map(fn {assigns, socket} ->
      socket
      |> assign_generic(assigns)
    end)
  end

  defp maybe_assign_provided(socket, assigns, false), do: {assigns, socket}

  defp maybe_assign_provided(socket, assigns, _true),
    do: socket |> assign_generic(assigns)

  def can?(subject, verbs, object, opts \\ []) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Boundaries) do
      maybe_apply(Bonfire.Boundaries, :can?, [subject, verbs, object, opts])
    else
      opts[:fallback] || false
    end
  end

  @doc """
  Inserts one or many items in an existing stream.
  See `Phoenix.LiveView.stream_insert/4` for opts.
  """
  def maybe_stream_insert(%{assigns: %{streams: _}} = socket, name, items, opts)
      when is_list(items) do
    Phoenix.LiveView.stream(socket, name, items, opts)
  end

  def maybe_stream_insert(%{assigns: %{streams: _}} = socket, name, item, opts) do
    debug(opts)

    if opts[:reset] do
      Phoenix.LiveView.stream(socket, name, [item], opts)
    else
      Phoenix.LiveView.stream_insert(socket, name, item, opts)
    end
  end

  def maybe_stream_insert(socket, name, items, _opts) do
    error(
      socket.assigns,
      "Could not find stream '#{name}' to render data in. Will set as regular assign instead"
    )

    socket
    |> assign_generic(name, items)
  end

  defmacro live_aliases(aliases, path, live_view, action \\ nil, opts \\ []) do
    quote bind_quoted: binding() do
      for alt <- aliases do
        live(String.replace(path, ":alias", alt), live_view, action, opts)
      end
    end
  end
end
