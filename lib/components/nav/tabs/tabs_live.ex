defmodule Bonfire.UI.Common.TabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop tabs, :list, required: true
  prop selected_tab, :string, default: nil
  prop path_prefix, :string, default: "?tab="

  @doc "What LiveHandler and/or event name to send the patch event to (optional)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to (optional)"
  prop event_target, :string, default: nil
end
