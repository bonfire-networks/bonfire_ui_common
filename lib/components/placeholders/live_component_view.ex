defmodule Bonfire.UI.Common.LiveComponentView do
  @moduledoc """
  Special LiveView used for a helper function which allows loading LiveComponents 
  """

  use Bonfire.UI.Common.Web, :live_view

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
    ~H"""
    <.live_component
      :if={
        (@component_module || @live_action) &&
          module_enabled?(@component_module || @live_action, @__context__)
      }
      module={@component_module || @live_action}
      id={@component_module || @live_action}
      {@attrs}
    />
    """
  end
end
