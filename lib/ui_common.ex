defmodule Bonfire.UI.Common do
  @moduledoc """
  A library of common utils and helpers used across Bonfire extensions
  """
  use Bonfire.Common.Utils
  import Bonfire.Common.URIs

  defmacro __using__(opts) do
    quote do
      use Bonfire.Common.Utils
      import Bonfire.UI.Common
      import Bonfire.Common.URIs
    end
  end

  def assign_global(socket, assigns) when is_map(assigns), do: assign_global(socket, Map.to_list(assigns))
  def assign_global(socket, assigns) when is_list(assigns) do
    socket
    |> Phoenix.LiveView.assign(assigns)
    # being naughty here, let's see how long until Surface breaks it:
    |> Phoenix.LiveView.assign(:__context__,
                          Map.get(socket.assigns, :__context__, %{})
                          |> Map.merge(maybe_to_map(assigns))
    ) #|> debug("assign_global")
  end
  def assign_global(socket, {_, _} = assign) do
    assign_global(socket, [assign])
  end
  def assign_global(socket, assign, value) do
    assign_global(socket, {assign, value})
  end
  # def assign_global(socket, assign, value) do
  #   socket
  #   |> Phoenix.LiveView.assign(assign, value)
  #   |> Phoenix.LiveView.assign(:global_assigns, [assign] ++ Map.get(socket.assigns, :global_assigns, []))
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

  def assigns_merge(%Phoenix.LiveView.Socket{} = socket, assigns, new) when is_map(assigns) or is_list(assigns), do: socket |> Phoenix.LiveView.assign(assigns_merge(assigns, new))
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
        |> Text.maybe_markdown_to_html()
        |> Text.external_links() # transform internal links for LiveView navigation
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
  defp socket_connected_or_user?(%Bonfire.Data.Identity.User{}), do: true
  defp socket_connected_or_user?(_), do: false


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
      live_exception(socket, return_key, "You seem to have provided an incorrect data type (eg. an invalid ID)", error, __STACKTRACE__)
    error in Ecto.ConstraintError ->
      live_exception(socket, return_key, "You seem to be referencing an invalid object ID, or trying to insert duplicated data", error, __STACKTRACE__)
    error in FunctionClauseError ->
      # debug(error)
      with %{
        arity: arity,
        function: function,
        module: module
      } <- error do
        live_exception(socket, return_key, "The function #{function}/#{arity} in module #{module} didn't receive data in a format it can recognise", error, __STACKTRACE__)
      else error ->
        live_exception(socket, return_key, "A function didn't receive data in a format it can recognise", error, __STACKTRACE__)
      end
    error in WithClauseError ->
      with %{
        term: provided
      } <- error do
        live_exception(socket, return_key, "A 'with condition' didn't receive data in a format it can recognise", provided, __STACKTRACE__)
      else error ->
        live_exception(socket, return_key, "A 'with condition' didn't receive data in a format it can recognise", error, __STACKTRACE__)
      end
    cs in Ecto.Changeset ->
        live_exception(socket, return_key, "The data provided caused an exceptional error and could do not be inserted or updated: "<>error_msg(cs), cs, nil)
    error ->
      live_exception(socket, return_key, "The app encountered an unexpected error", error, __STACKTRACE__)
  catch
    :exit, error ->
      live_exception(socket, return_key, "An exceptional error caused the operation to stop", error, __STACKTRACE__)
    :throw, error ->
      live_exception(socket, return_key, "An exceptional error was thrown", error, __STACKTRACE__)
    error ->
      # error(error)
      live_exception(socket, return_key, "An exceptional error occured", error, __STACKTRACE__)
  end

  def undead_error(error, socket, return_key \\ :noreply) do
   case error do
      {:ok, %Phoenix.LiveView.Socket{} = socket} -> {:ok, socket}
      {:ok, %Phoenix.LiveView.Socket{} = socket, data} -> {:ok, socket, data}
      {:noreply, %Phoenix.LiveView.Socket{} = socket} -> {:noreply, socket}
      {:reply, data, %Phoenix.LiveView.Socket{} = socket} -> {:reply, data, socket}
      {:error, reason} -> undead_error(reason, socket, return_key)
      {:error, reason, extra} -> live_exception(socket, return_key, "There was an error: #{inspect reason}", extra)
      :ok -> {return_key, socket} # shortcut to return nothing
      {:ok, _other} -> {return_key, socket}
      %Ecto.Changeset{} = cs -> live_exception(socket, return_key, "The data provided seems invalid and could not be inserted or updated: "<>error_msg(cs), cs)
      %{__struct__: struct} = act when struct == Bonfire.Epics.Act -> live_exception(socket, return_key, "The act was not completed: ", act)
      %{__struct__: struct} = epic when struct == Bonfire.Epics.Epic -> live_exception(socket, return_key, "There epic was not completed: "<>error_msg(epic), epic.errors)
      not_found when not_found in [:not_found, "Not found", 404] -> live_exception(socket, return_key, "Not found")
      msg when is_binary(msg) -> live_exception(socket, return_key, msg)
      ret -> live_exception(socket, return_key, "Oops, this resulted in something unexpected", ret)
    end
  end

  defp live_exception(socket, return_key, msg, exception \\ nil, stacktrace \\ nil, kind \\ :error)

  defp live_exception(socket, {:mount, return_key}, msg, exception, stacktrace, kind) do
    with {:error, msg} <- debug_exception(msg, exception, stacktrace, kind) do
      {return_key, Phoenix.LiveView.put_flash(socket, :error, error_msg(msg)) |> Phoenix.LiveView.push_redirect(to: "/error")}
    end
  end

  defp live_exception(%{assigns: %{__context__: %{current_url: current_url}}} = socket, return_key, msg, exception, stacktrace, kind) when is_binary(current_url) do
    with {:error, msg} <- debug_exception(msg, exception, stacktrace, kind) do
      {return_key, Phoenix.LiveView.put_flash(socket, :error, error_msg(msg)) |> Phoenix.LiveView.push_patch(to: current_url)}
    end
  end

  defp live_exception(socket, return_key, msg, exception, stacktrace, kind) do
    with {:error, msg} <- debug_exception(msg, exception, stacktrace, kind) do
      {return_key, Phoenix.LiveView.put_flash(socket, :error, error_msg(msg)) |> Phoenix.LiveView.push_patch(to: path(socket.view))}
    end
  rescue
    FunctionClauseError -> # for cases where the live_path may need param(s) which we don't know about
      {return_key, Phoenix.LiveView.put_flash(socket, :error, error_msg(msg)) |> Phoenix.LiveView.push_redirect(to: "/error")}
  end

end
