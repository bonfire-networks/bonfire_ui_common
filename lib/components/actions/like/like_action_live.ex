defmodule Bonfire.UI.Common.LikeActionLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :any
  prop object_type, :any
  prop object_boundary, :any, default: nil
  prop like_count, :any, default: 0
  # prop label, :string, default: nil
  # prop showing_within, :atom, default: nil
  prop my_like, :any, default: nil

  def preload(list_of_assigns),
    do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns, caller_module: __MODULE__)

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
