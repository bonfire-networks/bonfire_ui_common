defmodule Bonfire.UI.Common.LivePlugs.Helpers do
  @moduledoc "Like a plug, but for a liveview"
  alias Bonfire.UI
  use UI.Common
  # alias Bonfire.UI.Common.LivePlugs

  def on_mount(modules, params, session, socket) when is_list(modules) do
    UI.Common.undead_on_mount(socket, fn ->
      socket = init_mount(params, session, socket)

      case Enum.reduce_while(modules, socket, fn module, socket ->
             with {:halt, socket} <-
                    maybe_apply(module, :on_mount, [:default, params, session, socket]) do
               # to halt both the reduce and the on_mount
               {:halt, {:halt, socket}}
             end
           end) do
        {:halt, socket} -> {:halt, socket}
        {:cont, socket} -> mount_done(socket)
        socket -> mount_done(socket)
      end
    end)
  end

  def on_mount(module, params, session, socket) when is_atom(module) do
    on_mount([module], params, session, socket)
    # UI.Common.undead_on_mount(socket, fn ->
    #   with {:cont, socket} <-
    #          init_mount(params, session, socket)
    #          |> maybe_apply(module, :on_mount, [:default, params, session, ...]) do
    #     mount_done(socket)
    #   end
    # end)
  end

  defp init_mount(:not_mounted_at_router, session, socket) do
    # for embedding views in views/components using `live_render`
    # note that these views can't contain any handle_params
    ok_unwrap(init_socket(stringify_keys(session["params"]), socket))
  end

  defp init_mount(params, _session, socket) do
    debug("MOUNTING SOCKET")

    with {:ok, socket} <-
           socket
           |> Phoenix.LiveView.attach_hook(
             :params_to_assigns,
             :handle_params,
             &params_to_assigns/3
           )
           #  |> Phoenix.LiveView.attach_hook(
           #    :send_persistent_assigns_after_render,
           #    :after_render,
           #    &send_persistent_assigns_after_render/1
           #  )
           |> init_socket(params, ...) do
      socket
    end

    # rescue
    #   e in RuntimeError ->
    #     # workaround to `cannot attach hook with id :params_to_assigns on :handle_params because the view was not mounted at the router with the live/3 macro` on hybrid views
    #     warn(e)
    #     ok_unwrap(init_socket(params, socket))
  end

  defp init_socket(params, socket) do
    current_view =
      socket.view
      |> debug()

    current_app =
      Extend.application_for_module(current_view)
      |> debug()

    current_extension =
      Bonfire.Common.ExtensionModule.extension(current_app)
      |> debug()

    socket_connected? =
      Phoenix.LiveView.connected?(socket)
      |> debug("MOUNTING SOCKET for #{current_view}")

    # TEMP: monitor memory used by the LV and children
    # Bonfire.Common.MemoryMonitor.start_link("#{current_view} (connected? #{socket_connected?})")

    Bonfire.Common.TestInstanceRepo.maybe_declare_test_instance(socket.endpoint)

    connect_params =
      if socket_connected?, do: Phoenix.LiveView.get_connect_params(socket), else: %{}

    user_ip =
      if peer_data = maybe_get_connect_info(socket, :peer_data),
        do: peer_data.address |> :inet_parse.ntoa() |> to_string()

    {:ok,
     if(module_enabled?(Surface), do: Surface.init(socket), else: socket)
     |> assign_global(
       current_view: current_view,
       current_app: current_app,
       current_extension: current_extension,
       current_params: params,
       user_agent: maybe_get_connect_info(socket, :user_agent),
       user_ip: user_ip |> warn("peer_data"),
       #  connect_params: connect_params,
       csrf_socket_token: connect_params["_csrf_token"],
       live_action: e(socket, :assigns, :live_action, nil),
       socket_connected?: socket_connected?
     )}
  end

  defp maybe_get_connect_info(socket, key) do
    #  if current_view !=Bonfire.UI.Common.PersistentLive and 
    if socket.private[:connect_info], do: Phoenix.LiveView.get_connect_info(socket, key)
  end

  defp mount_done(socket) do
    if not module_enabled?(socket.view, socket) do
      # check here because we need current_user
      error(
        l(
          "This feature (from extension %{app}) is disabled. You can enabled it in Settings -> Extensions ",
          app:
            e(socket.assigns, :current_extension, :name, nil) ||
              e(socket.assigns, :current_app, nil)
        )
      )
    else
      {:cont,
       assign_global(
         socket,
         ui_compact: Settings.get([:ui, :compact], nil, socket.assigns)
       )}

      # |> debug()
    end
  end

  # def send_persistent_assigns_after_render(socket) do
  #   maybe_send_persistent_assigns(socket)
  #   socket
  # end

  defp params_to_assigns(params, uri, socket) do
    socket = assign_default_params(params, uri, socket)

    # in case we're browsing between LVs, send assigns (eg current_user to PersistentLive's process)
    # if socket_connected?(socket), do: LivePlugs.maybe_send_persistent_assigns(socket)

    {:cont, socket}
  end

  def assign_default_params(params, uri, socket) do
    uri = URI.parse(uri)

    socket
    |> assign_global(
      current_params: params,
      current_url: "#{uri.path}##{uri.fragment}"
    )
    |> Iconify.maybe_set_favicon(
      e(socket.assigns, :current_extension, :icon, nil) ||
        e(socket.assigns, :current_extension, :emoji, nil)
    )
  end
end
