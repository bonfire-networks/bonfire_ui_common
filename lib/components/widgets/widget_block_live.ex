defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class,
    default:
      "w-full p-3 flex-auto mx-auto rounded-xl border border-base-content/5 bg-base-content/5"

  prop title_class, :css_class, default: "pb-3 text-lg font-bold tracking-wide"

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true
end
