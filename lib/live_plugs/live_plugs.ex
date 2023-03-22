defmodule Bonfire.UI.Common.LivePlugs do
  @moduledoc "Like a plug, but for a liveview"
  use Bonfire.UI.Common

  @compile {:inline, live_plug_: 4}

  # TODO: put in config
  @default_plugs [
    Bonfire.UI.Common.LivePlugs.StaticChanged,
    Bonfire.UI.Common.LivePlugs.Csrf,
    Bonfire.UI.Common.LivePlugs.Locale
  ]

  # Bonfire.UI.Common.LivePlugs.AllowTestSandbox

  def on_mount(modules, params, session, socket) when is_list(modules) do
    socket
    |> undead_on_mount(fn ->
      case Enum.reduce_while(modules ++ @default_plugs, socket, fn module, socket ->
             with {:halt, socket} <-
                    maybe_apply(module, :on_mount, [:default, params, session, socket]) do
               # to halt both the reduce and the on_mount
               {:halt, {:halt, socket}}
             end
           end) do
        {:halt, socket} -> {:halt, socket}
        {:cont, socket} -> cont_init_socket(socket)
        socket -> cont_init_socket(socket)
      end
    end)
  end

  def on_mount(module, params, session, socket) when is_atom(module) do
    socket
    |> undead_on_mount(fn ->
      with {:cont, socket} <- maybe_apply(module, :on_mount, [:default, params, session, socket]) do
        cont_init_socket(socket)
      end
    end)
  end

  defp cont_init_socket(socket) do
    with {:ok, socket} <- init_socket(socket) do
      {:cont, socket}
    end
  end

  # TODO: deprecate in favour of on_mount
  def live_plug(params, session, socket, list) when is_list(list),
    do: live_plug_(@default_plugs ++ list, {:ok, socket}, params, session)

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
      with {:ok, socket} <- init_socket(socket),
           {:ok, socket} <-
             apply(fun, [
               params,
               session,
               socket
             ]) do
        maybe_send_persistent_assigns(socket)

        {:ok, socket}
      end
    end)
  end

  defp init_socket(socket) do
    current_app = Application.get_application(socket.view)
    current_extension = Bonfire.Common.ExtensionModule.extension(current_app)

    if not is_nil(current_app) and
         (not extension_enabled?(current_app, :instance) or
            not extension_enabled?(current_app, socket)) do
      if not extension_enabled?(current_app, :instance) do
        error(
          l(
            "Sorry, %{app} is not enabled on this instance. You may want to get in touch with your instance admin(s)...",
            app: current_extension[:name] || current_app
          )
        )
      else
        error(
          l("You have not enabled %{app}. You can do so in Settings -> Extensions.",
            app: current_extension[:name] || current_app
          )
        )
      end
    else
      Bonfire.Common.TestInstanceRepo.maybe_declare_test_instance(socket.endpoint)

      {:ok,
       socket
       |> assign_global(
         current_view: socket.view,
         current_app: current_app,
         current_extension: current_extension,
         live_action: e(socket, :assigns, :live_action, nil),
         socket_connected?: Phoenix.LiveView.connected?(socket)
       )}
    end
  end

  def maybe_send_persistent_assigns(assigns \\ nil, socket) do
    # in case we're browsing between LVs, send some assigns (eg page_title to PersistentLive's process)
    if socket_connected?(socket),
      do:
        Bonfire.UI.Common.PersistentLive.maybe_send_assigns(
          assigns || socket.assigns
          # |> Map.new()
          # |> Map.put_new(:nav_items, nil)
        )
  end
end
