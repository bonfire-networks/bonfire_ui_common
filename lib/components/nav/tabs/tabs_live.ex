defmodule Bonfire.UI.Common.TabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop tabs, :any, required: true
  prop selected_tab, :string, default: nil
  prop path_prefix, :string, default: "?tab="
  prop path_suffix, :string, default: nil

  prop link_component, :atom, default: LinkPatchLive

<<<<<<< HEAD
  prop class, :css_class, default: "flex gap-3 pt-1 md:pt-4 p-3 px-4 bg-base-100"

  prop tab_class, :css_class,
    default:
      "btn hover:bg-base-content hover:!text-base-300 btn-sm !max-h-[1.75rem] !min-h-[1.75rem] !h-[1.75rem] rounded-full font-normal capitalize bg-base-content/10 text-base-content/70 feed_tab border-none"
=======
  prop class, :css_class
  prop tab_class, :css_class
>>>>>>> 175468d (ui)

  prop tab_primary_class, :css_class, default: "btn-primary"
  @doc "What LiveHandler and/or event name to send the patch event to (optional)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to (optional)"
  prop event_target, :string, default: nil
end
