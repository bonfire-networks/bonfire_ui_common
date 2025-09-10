defmodule Bonfire.UI.Common.LivePlugs.Helpers do
  @moduledoc "Like a plug, but for a liveview"
  alias Bonfire.UI
  use UI.Common
  # alias Bonfire.UI.Common.LivePlugs

  def on_mount(modules, params, session, socket) when is_list(modules) do
    UI.Common.undead_on_mount(socket, fn ->
      socket =
        init_mount(params, session, socket)
        |> Phoenix.Component.assign(:on_mount_plugs, modules)

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
    from_ok(init_socket(stringify_keys(session["params"]), socket))
  end

  defp init_mount(params, _session, socket) do
    # debug("MOUNTING SOCKET")

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
    #     from_ok(init_socket(params, socket))
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
      socket_connected?(socket)
      |> debug("MOUNTING #{current_view} with socket_connected?")

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
       user_ip: user_ip |> debug("user_ip"),
       #  connect_params: connect_params,
       csrf_socket_token: connect_params["_csrf_token"],
       live_action: e(assigns(socket), :live_action, nil),
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
      {:halt,
       socket
       |> assign_error(
         l(
           "This feature (from extension %{app}) is disabled. You can enabled it in Settings -> Extensions ",
           app:
             e(assigns(socket), :current_extension, :name, nil) ||
               e(assigns(socket), :current_app, nil)
         )
       )
       |> redirect_to("/error/disabled")}
    else
      {:cont,
       assign_global(
         socket,
         ui_compact: Settings.get([:ui, :compact], nil, assigns(socket))
       )}

      # |> debug()
    end
  end

  # def send_persistent_assigns_after_render(socket) do
  #   maybe_send_persistent_assigns(socket)
  #   socket
  # end

  defp params_to_assigns(params, url, socket) do
    # host_uri =
    #   socket.host_uri
    #   |> debug("socket INFO")

    uri = URI.parse(url)
    # url = uri |> String.trim(to_string(host_uri)) |> String.trim("#") |> debug()
    current_url = uri.path || url

    # save the path in Process dictionary (use for e.g. by Gettext.POAnnotator)
    Process.put(:bonfire_current_url, current_url)

    # route_info =
    #   Phoenix.Router.route_info(socket.router || Bonfire.Web.Router, "GET", url, host_uri.host)
    #   |> debug("ROUTE INFO")

    socket =
      assign_default_params(params, socket,
        current_params: params,
        current_url: current_url,
        # current_route: e(route_info, :route, nil)
        force_static: params["force_render"] == "static",
        force_live: params["force_render"] == "live"
      )

    # in case we're browsing between LVs, send assigns (eg current_user to PersistentLive's process)
    # if socket_connected?(socket), do: LivePlugs.maybe_send_persistent_assigns(socket)

    # case e(route_info, :pipe_through, []) do
    #   [] -> 
    {:cont, socket}
    #   pipe_through ->
    # # WIP: run LivePlugs here (instead of, or mayebe better as a fallback) in on_mount so they can be defined by the router just like regular routes instead of in each module
    #     debug(pipe_through, "PIPE THROUGH")
    #     mounted_plugs = e(assigns(socket), :on_mount_plugs, [])
    #     |> debug("MOUNTED PLUGS")
    #     pipeline_names = Bonfire.UI.Common.LivePlugModule.pipeline_names()
    #     {:cont, socket}
    # end
  end

  defp assign_default_params(params, socket, assigns) do
    socket
    |> assign_global(assigns)
    |> Iconify.maybe_set_favicon(
      e(assigns(socket), :current_extension, :icon, nil) ||
        e(assigns(socket), :current_extension, :emoji, nil)
    )
  end
end
