defmodule Bonfire.UI.Common.PagesHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop sidebar_widgets, :list, default: []
  prop page_title, :string, default: nil
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop nav_items, :list, default: []
  
end