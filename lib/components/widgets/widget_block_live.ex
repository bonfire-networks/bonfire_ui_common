defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class, default: "relative w-full mx-auto rounded bg-base-100"

  prop title_class, :css_class,
    default: "flex items-center p-3 pb-2 rounded-t-md text-lg font-bold text-base-content"

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true
end
