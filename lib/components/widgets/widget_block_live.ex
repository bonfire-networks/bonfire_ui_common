defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class, default: "w-full p-4 flex-auto mx-auto bonfire-wrapper"

  prop title_class, :css_class,
    default: "pb-1 text-sm font-semibold uppercase tracking-wider text-base-content/50"

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true
end
