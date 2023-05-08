defmodule Bonfire.UI.Common.BlockButtonProfileLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :string, required: true
  prop class, :css_class, default: nil
  prop icon_class, :css_class, default: nil
  prop label, :string, default: nil
  prop ghosted?, :boolean, default: nil
  prop silenced?, :boolean, default: nil
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil
  prop hide_icon, :boolean, default: false
  prop hide_text, :boolean, default: false
  prop show_follow_button, :boolean, default: false

  def preload([%{skip_preload: true}] = list_of_assigns) do
    list_of_assigns
  end

  def preload(list_of_assigns) do
    Bonfire.Social.Block.LiveHandler.preload(list_of_assigns, caller_module: __MODULE__)
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
