defmodule Bonfire.UI.Common.FollowButtonLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :string, required: true
  prop path, :string, default: nil
  prop class, :css_class, default: nil
  prop icon_class, :css_class, default: nil
  prop label, :string, default: nil
  prop my_follow, :boolean, default: nil
  prop hide_icon, :boolean, default: false
  prop hide_text, :boolean, default: false

  def preload(list_of_assigns),
    do: Bonfire.Social.Follows.LiveHandler.preload(list_of_assigns, caller_module: __MODULE__)

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
