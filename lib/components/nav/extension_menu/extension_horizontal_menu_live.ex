defmodule Bonfire.UI.Common.ExtensionHorizontalMenuLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop nav_items, :any, default: nil
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
end
