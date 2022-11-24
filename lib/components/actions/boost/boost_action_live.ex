defmodule Bonfire.UI.Common.BoostActionLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object, :any
  prop object_type, :any
  prop boost_count, :any
  prop showing_within, :any
  prop my_boost, :any, default: nil

  def preload(list_of_assigns),
    do: Bonfire.Social.Boosts.LiveHandler.preload(list_of_assigns)

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
