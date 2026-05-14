defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class,
    default: "w-full p-4 flex-auto mx-auto rounded-box border border-base-content/20"

  prop title_class, :css_class,
    default: "pb-2 text-xs font-medium uppercase tracking-wide text-base-content/60"

  prop empty, :boolean, default: false
  prop empty_message, :string, default: nil
  prop empty_icon, :string, default: "ph:sparkle-duotone"

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "Override the default empty-state placeholder."
  slot empty_state

  @doc "The main content of the widget"
  slot default, required: true
end
