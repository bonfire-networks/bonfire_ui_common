defmodule Bonfire.UI.Common.ErrorHandling do
  use Bonfire.Common.Utils
  alias Bonfire.UI

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

    Needle.NotFound ->
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

    error in ArgumentError ->
      error(__STACKTRACE__, inspect(error))

      term_error(
        l("Sorry, a function didn't receive the data it expected"),
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

  defp with_return_key({:error, e}, _) do
    {:error, e}
  end

  defp with_return_key(socket_or_assigns, {_, nil}) do
    socket_or_assigns
  end

  defp with_return_key(socket_or_conn, {_, return_key}) do
    {return_key, socket_or_conn}
  end

  defp with_return_key(socket_or_assigns, nil) do
    socket_or_assigns
  end

  defp with_return_key(socket_or_conn, return_key) do
    {return_key, socket_or_conn}
  end

  defp go_login(msg, socket, return_key) when is_atom(return_key),
    do: go_login(msg, socket, {nil, return_key})

  defp go_login(msg, socket, {via, return_key}) when via in [:update, :render] do
    msg = e(msg, :message, l("You need to log in first."))

    socket =
      socket
      |> UI.Common.assign_generic(:__replace_render__with__, msg)
      |> UI.Common.assign_error(msg)

    UI.Common.redirect_self("/login")

    with_return_key(
      socket,
      return_key
    )
  end

  defp go_login(msg, socket, {_, return_key}) do
    with_return_key(
      socket
      |> UI.Common.assign_error(e(msg, :message, l("You need to log in first.")))
      |> UI.Common.redirect_to("/login"),
      return_key
    )
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

  defp undead_maybe_handle_error(return, socket, return_key) do
    case return do
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
        with_return_key(socket, return_key)

      %Phoenix.LiveView.Rendered{} = rendered ->
        rendered

      %Phoenix.LiveView.Component{id: id, component: component, assigns: assigns} ->
        Phoenix.Component.live_component(assigns |> Enum.into(%{id: id, module: component}))

      {:noreply, %Plug.Conn{} = conn} ->
        {:noreply, conn}

      %Plug.Conn{} = conn ->
        with_return_key(conn, return_key)

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
        with_return_key(socket, return_key)

      {:ok, _other} ->
        with_return_key(socket, return_key)

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
        # IO.inspect(epic, label: "eppic")
        live_exception(
          socket,
          return_key,
          l("Sorry, a series of actions could not be completed") <>
            ": \n#{Errors.error_msg(epic)}",
          epic.errors,
          e(List.first(epic.errors), :stacktrace, nil)
        )

      not_found when not_found in [:not_found, "Not found", 404] ->
        live_exception(socket, return_key, l("Not found"))

      msg when is_binary(msg) ->
        live_exception(socket, return_key, msg)

      nil ->
        IO.warn("Received nil instead of a socket")
        live_exception(socket, return_key, l("Sorry, no answer was received"))

      ret ->
        debug(ret, "unexpected ret type")

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
         %Bonfire.Fail{code: code} = msg,
         exception,
         stacktrace,
         kind
       ) do
    with {:error, msg} <-
           Errors.debug_exception(msg, exception, stacktrace, kind, as_markdown: true) do
      with_return_key(
        socket
        |> UI.Common.assign_error(msg)
        |> UI.Common.redirect_to("/error/#{code}"),
        return_key
      )
    end
  end

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
      with_return_key(
        socket
        |> UI.Common.assign_error(msg)
        |> UI.Common.redirect_to("/error"),
        return_key
      )
    end
  end

  defp live_exception(
         socket,
         {via, _return_key} = return_keys,
         msg,
         exception,
         stacktrace,
         kind
       )
       when via in [:update, :render] do
    with {:error, msg} <-
           Errors.debug_exception(msg, exception, stacktrace, kind, as_markdown: true) do
      socket =
        socket
        |> UI.Common.assign_generic(:__replace_render__with__, msg)
        |> UI.Common.assign_error(msg)
        |> debug("ssss #{inspect(return_keys)}")

      #   UI.Common.redirect_self("/error")
      #   |> debug("rrrrr")

      with_return_key(socket, return_keys)
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
  #       UI.Common.assign_error(
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
      with_return_key(
        socket
        |> UI.Common.assign_error(msg),
        return_key
      )
    end
  rescue
    # FIXME: handle cases where the live_path requires param(s)
    FunctionClauseError ->
      with_return_key(
        socket
        |> UI.Common.assign_error(msg)
        |> UI.Common.redirect_to("/error"),
        return_key
      )
  end

  defp db_error,
    do:
      l(
        "Sorry, the data provided has missing fields or is invalid and could do not be inserted or updated"
      )
end
