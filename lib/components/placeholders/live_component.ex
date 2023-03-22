defmodule Bonfire.UI.Common.LiveComponent do
  @moduledoc """
  Special LiveView used for a helper function which allows loading LiveComponents directly in regular non-live Phoenix views: `live_render_component(@conn, MyLiveComponent)`
  """

  use Bonfire.UI.Common.Web, :live_view

  on_mount {LivePlugs, []}

  def mount(
        _params,
        %{"load_live_component" => load_live_component} = _session,
        socket
      ) do
    {:ok, assign(socket, :load_live_component, load_live_component)}
  end

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    load_live_component = e(assigns, :load_live_component, nil)

    ~L"""
      <%= if load_live_component and module_enabled?(load_live_component), do: live_component(
      load_live_component,
      assigns
    ) %>
    """
  end
end
