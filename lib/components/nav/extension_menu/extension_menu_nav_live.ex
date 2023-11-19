defmodule Bonfire.UI.Common.ExtensionMenuNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop nav_items, :list, default: []
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop skip_badges, :any, default: false
end
