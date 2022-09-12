defmodule Bonfire.UI.Common.NavSidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop items, :list, required: true
  prop sidebar_widgets, :list, default: []

  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
end
