defmodule Bonfire.UI.Common.WidgetAppsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string, default: nil
  prop cols, :integer, default: 3
end
