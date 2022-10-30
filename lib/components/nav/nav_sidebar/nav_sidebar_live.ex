defmodule Bonfire.UI.Common.NavSidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop nav_items, :list, default: []

end
