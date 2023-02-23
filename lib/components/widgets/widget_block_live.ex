defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class, default: "relative w-full mx-auto rounded bg-base-100"

  prop title_class, :css_class,
    default:
      "mx-3 py-3 border-b border-base-content/10 text-sm font-medium tracking-wide text-base-content/70"

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true
end
