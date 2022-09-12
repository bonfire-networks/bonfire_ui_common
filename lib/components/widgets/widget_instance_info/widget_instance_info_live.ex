defmodule Bonfire.UI.Common.WidgetInstanceInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Show a large instance or app icon?"
  prop display_banner, :boolean, default: true

  declare_widget("Instance Details")
end
