defmodule Bonfire.UI.Common.WidgetMetaItemLive do
  @doc "A small icon + text metadata row for use inside sidebar widgets."
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :css_class, default: "flex items-center gap-2.5"
  prop text_class, :css_class, default: "text-xs text-base-content/50"

  @doc "The icon to display (use #Icon or any element)"
  slot icon

  slot default, required: true
end
