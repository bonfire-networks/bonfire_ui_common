defmodule Bonfire.UI.Common.LivePlugs do
  @moduledoc "Like a plug, but for a liveview"
  use Bonfire.UI.Common

  @compile {:inline, live_plug_: 4}

  @extra_plugs [Bonfire.UI.Common.LivePlugs.AllowTestSandbox]

  def live_plug(params, session, socket, list) when is_list(list),
    do: live_plug_(@extra_plugs ++ list, {:ok, socket}, params, session)

  defp live_plug_([], ret, _, _), do: ret

  defp live_plug_(_, {:halt, socket}, _, _), do: {:ok, socket}

  defp live_plug_([{mod, fun, args} | y], {:ok, socket}, params, session)
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do:
         live_plug_(
           y,
           apply(mod, fun, [params, session, socket | args]),
           params,
           session
         )

  defp live_plug_([{mod, fun} | y], {:ok, socket}, params, session)
       when is_atom(mod) and is_atom(fun),
       do:
         live_plug_(
           y,
           apply(mod, fun, [params, session, socket]),
           params,
           session
         )

  defp live_plug_([{mod, args} | y], {:ok, socket}, params, session)
       when is_atom(mod) and is_list(args),
       do:
         live_plug_(
           y,
           apply(mod, :mount, [params, session, socket | args]),
           params,
           session
         )

  defp live_plug_([mod | y], {:ok, socket}, params, session) when is_atom(mod),
    do:
      live_plug_(
        y,
        apply(mod, :mount, [params, session, socket]),
        params,
        session
      )

  defp live_plug_([fun | y], {:ok, socket}, params, session)
       when is_function(fun, 3),
       do:
         live_plug_(
           y,
           apply_undead_mounted(socket, fun, params, session),
           params,
           session
         )

  defp live_plug_([{fun, args} | y], {:ok, socket}, params, session)
       when is_list(args) and is_function(fun),
       do:
         live_plug_(
           y,
           apply_undead_mounted(socket, fun, params, session),
           params,
           session
         )

  defp live_plug_(_, other, _, _), do: other

  defp apply_undead_mounted(socket, fun, :not_mounted_at_router, session) do
    # for embedding views in views/components using `live_render`
    # note that these views can't contain any handle_params
    socket
    |> apply_undead_mounted(fun, stringify_keys(session["params"]), session)
  end

  defp apply_undead_mounted(socket, fun, params, session) do
    # needed if using Surface in a normal LiveView
    #  debug(surfacing: module_enabled?(Surface))
    if(module_enabled?(Surface), do: Surface.init(socket), else: socket)
    |> undead_mount(fn ->
      apply(fun, [
        params,
        session,
        socket
        |> assign_global(
          current_view: socket.view,
          current_app: Application.get_application(socket.view)
        )
      ])
    end)
  end
end
