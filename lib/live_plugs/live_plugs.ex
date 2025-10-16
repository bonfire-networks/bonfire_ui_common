defmodule Bonfire.UI.Common.LivePlugs do
  @moduledoc "Like a plug, but for a liveview"
  alias Bonfire.UI
  use UI.Common

  @behaviour Bonfire.UI.Common.LivePlugModule

  def default_plugs_before,
    do:
      Bonfire.Common.Config.get(
        [__MODULE__, :default_plugs, :before],
        [
          UI.Common.LivePlugs.StaticChanged,
          UI.Common.LivePlugs.Csrf,
          # UI.Common.LivePlugs.Locale,
          # for tests (TODO: only include in test env?)
          Bonfire.UI.Common.LivePlugs.AllowTestSandbox
        ],
        name: l("Live plugs"),
        description: l("Default plugs to run on LiveViews (*before* any custom ones)")
      )

  def default_plugs_after,
    do:
      Bonfire.Common.Config.get(
        [__MODULE__, :default_plugs, :after],
        [
          UI.Common.LivePlugs.Locale
        ],
        name: l("Live plugs"),
        description: l("Default plugs to run on LiveViews (*after* any custom ones)")
      )

  def on_mount(modules, params, session, socket) when is_list(modules) do
    Bonfire.UI.Common.LivePlugs.Helpers.on_mount(
      default_plugs_before() ++ modules ++ default_plugs_after(),
      params,
      session,
      socket
    )
  end

  def on_mount(module, params, session, socket) when is_atom(module) do
    on_mount([module], params, session, socket)
  end

  def maybe_send_persistent_assigns(assigns \\ nil, socket) do
    # in case we're browsing between LVs, send some assigns (eg current_user, page_title, etc to PersistentLive's process)
    if socket_connected?(socket),
      do:
        Bonfire.UI.Common.PersistentLive.maybe_send_assigns(
          assigns || assigns(socket)
          # |> Map.new()
          # |> Map.put_new(:nav_items, nil)
        ),
      else: debug("not connected, skip sending persistent assigns")
  end
end
