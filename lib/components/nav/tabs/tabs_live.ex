defmodule Bonfire.UI.Common.TabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop tabs, :any, required: true
  prop selected_tab, :string, default: nil
  prop path_prefix, :string, default: "?tab="
  prop path_suffix, :string, default: nil

  prop link_component, :atom, default: LinkPatchLive

  prop class, :css_class,
    default: "flex justify-start gap-3 p-4 mb-3 rounded-md shadow tabs-boxed tabs bg-base-100"

  prop tab_class, :css_class,
    default:
      "btn btn-sm rounded normal-case bg-base-content/10 text-neutral-content/80 feed_tab border-none"

  prop tab_primary_class, :css_class, default: "btn-primary"
  @doc "What LiveHandler and/or event name to send the patch event to (optional)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to (optional)"
  prop event_target, :string, default: nil
end
