defmodule Bonfire.UI.Common.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string
  prop class, :css_class, default: "relative w-full mx-auto rounded-md bg-base-100"
  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true

end
