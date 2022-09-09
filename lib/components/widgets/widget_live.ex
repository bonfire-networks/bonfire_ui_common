defmodule Bonfire.UI.Common.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget, :any, required: true

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil

end
