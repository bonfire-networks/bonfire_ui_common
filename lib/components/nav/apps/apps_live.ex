defmodule Bonfire.UI.Common.AppsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop nav_items, :list, default: []
  prop sidebar_widgets, :list, default: []
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
end
