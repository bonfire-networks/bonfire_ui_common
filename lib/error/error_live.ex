defmodule Bonfire.UI.Common.ErrorLive do
  use Bonfire.UI.Common.Web, :live_view

  def mount(%{"component" => "component"}, _, socket) do
    {:ok, socket}
  end

  def mount(_, _, _) do
    raise("User-triggered crash")
  end

  def render(assigns) do
    ~H"""
    <h1>Error</h1>
    <.live_component id="error" module={maybe_component(Bonfire.UI.Common.ErrorComponentLive)} />
    """
  end
end
