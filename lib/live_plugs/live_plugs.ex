defmodule Bonfire.UI.Common.LivePlugs do
  @moduledoc "Like a plug, but for a liveview"
  alias Bonfire.UI
  use UI.Common

  @behaviour Bonfire.UI.Common.LivePlugModule

  # TODO: put in config
  @default_plugs [
    UI.Common.LivePlugs.StaticChanged,
    UI.Common.LivePlugs.Csrf,
    # UI.Common.LivePlugs.Locale,
    # for tests (TODO: only include in test env?)
    Bonfire.UI.Common.LivePlugs.AllowTestSandbox
  ]

  @default_plugs_after [
    UI.Common.LivePlugs.Locale
  ]

  def on_mount(modules, params, session, socket) when is_list(modules) do
    Bonfire.UI.Common.LivePlugs.Helpers.on_mount(
      @default_plugs ++ modules ++ @default_plugs_after,
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
        )
  end
end
