defmodule Bonfire.UI.Common.FollowButtonLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object, :any, required: true
  prop class, :css_class, default: nil
  prop icon_class, :css_class, default: nil
  prop label, :string, default: nil
  prop my_follow, :boolean, default: nil
  prop hide_icon, :boolean, default: false
  prop hide_text, :boolean, default: false

  def preload(list_of_assigns),
    do: Bonfire.Social.Follows.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_event(
        action,
        attrs,
        socket,
        __MODULE__
      )
end
