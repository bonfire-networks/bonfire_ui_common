defmodule Bonfire.UI.Common.LoadingScreenLive do
  use Bonfire.UI.Common.Web, :function_component

  def render(assigns) do
    ~H"""
    <div class="flex w-full flex-col gap-4">
      <div class="skeleton h-32 w-full"></div>
      <div class="skeleton h-4 w-[50%]"></div>
      <div class="skeleton h-4 w-full"></div>
      <div class="skeleton h-4 w-full"></div>
    </div>
    """
  end
end
