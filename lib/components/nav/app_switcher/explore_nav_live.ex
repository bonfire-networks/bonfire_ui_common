defmodule Bonfire.UI.Common.ExploreNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop show_extensions_nav, :boolean, default: false
end
