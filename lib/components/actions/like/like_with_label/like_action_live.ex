defmodule Bonfire.UI.Common.LikeActionLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object, :any
  prop like_count, :any, default: 0
  # prop label, :string, default: nil
  # prop showing_within, :any, default: nil

  def preload(list_of_assigns),
    do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_event(
        action,
        attrs,
        socket,
        __MODULE__
      )
end
