defmodule Bonfire.UI.Common.WidgetAppMenuLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil
  prop nav_items, :list, default: []
  prop page, :string, default: nil
  prop selected_tab, :string, default: nil
end
