defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class, default: "flex-auto mx-auto rounded-xl bg-base-content/5"

  prop title_class, :css_class, default: "mx-3 py-3  text-base font-bold tracking-wide"

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true
end
