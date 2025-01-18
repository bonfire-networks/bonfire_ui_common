defmodule Bonfire.UI.Common.StatefulComponentView do
  @moduledoc """
  Special Surface View used for a helper function which allows loading LiveComponents 
  """

  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(
        _params,
        %{"load_live_component" => component} = _session,
        socket
      ) do
    {:ok, assign(socket, component_module: component, attrs: %{})}
  end

  def mount(_params, _session, socket),
    do: {:ok, assign(socket, component_module: nil, attrs: %{})}

  def render(assigns) do
    ~F"""
    <StatefulComponent
      :if={(@component_module || @live_action) &&
        module_enabled?(@component_module || @live_action, @__context__)}
      module={@component_module || @live_action}
      id={@component_module || @live_action}
      {...@attrs}
    />
    """
  end
end
