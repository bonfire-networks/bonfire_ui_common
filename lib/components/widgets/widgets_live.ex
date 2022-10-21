defmodule Bonfire.UI.Common.WidgetsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widgets, :any, required: true

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
end
