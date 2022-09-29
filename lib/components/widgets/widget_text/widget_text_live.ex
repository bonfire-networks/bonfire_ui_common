defmodule Bonfire.UI.Common.WidgetTextLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop text, :string, default: nil
  prop widget_title, :string, default: nil
  prop banner_image, :any, default: nil
  prop info, :map, default: nil
end
