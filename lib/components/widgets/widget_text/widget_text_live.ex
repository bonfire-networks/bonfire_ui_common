defmodule Bonfire.UI.Common.WidgetTextLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop text, :string
  prop widget_title, :string
  prop banner_image, :any
  prop info, :map
end
