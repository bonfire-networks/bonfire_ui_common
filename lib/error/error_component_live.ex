defmodule Bonfire.UI.Common.ErrorComponentLive do
  use Bonfire.UI.Common.Web, :live_component

  def update(_, _) do
    raise("User-triggered crash")
  end

  def render(assigns) do
    ~H"""
    <em>Error</em>
    """
  end

  def replace(assigns) do
    ~H"""
    <div data-role="render_error" class="prose p-2 text-xs">
      {markdown(@__replace_render__with__)}
    </div>
    """
  end
end
