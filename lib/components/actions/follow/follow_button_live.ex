defmodule Bonfire.UI.Common.FollowButtonLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object, :any
  prop class, :css_class
  prop icon_class, :css_class
  prop label, :string
  prop my_follow, :boolean
  prop hide_icon, :boolean, default: false
  prop hide_text, :boolean, default: false

  def preload(list_of_assigns), do: Bonfire.Social.Follows.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
