defmodule Bonfire.UI.Common.WidgetSectionLabelLive do
  @doc "An uppercase section divider label for use inside sidebar widgets."
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :css_class,
    default: "block pb-2 text-xs font-semibold uppercase tracking-wider text-base-content/40"

  slot default, required: true
end
