defmodule Bonfire.UI.Common.WidgetLinksLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop links, :any, default: []
  prop widget_title, :string, default: nil
end
