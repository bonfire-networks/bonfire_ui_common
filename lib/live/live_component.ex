defmodule Bonfire.UI.Common.LiveComponent do
  @moduledoc """
  Special LiveView used for a helper function which allows loading LiveComponents in regular Phoenix views: `live_render_component(@conn, MyLiveComponent)`
  """

  use Bonfire.UI.Common.Web, :live_view

  alias Bonfire.Me.Web.LivePlugs

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadSessionAuth,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(_params, %{"load_live_component" => load_live_component} = _session, socket) do

     {:ok, socket |> assign(:load_live_component, load_live_component)}
  end

  defp mounted(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
      ~L"""
      <%= if Map.has_key?(assigns, :load_live_component) and module_enabled?(assigns.load_live_component), do: live_component(
      @socket,
      assigns.load_live_component,
      assigns
    ) %>
    """
  end

end
