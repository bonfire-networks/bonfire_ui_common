defmodule Bonfire.UI.Common.InstancePinnedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop title, :string, default: nil
  prop object_types, :any, default: []
  prop entries, :any, default: []

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    entries = pinned_activities()
    {:ok, assign(socket, entries: entries)}
  end

  defp pinned_activities do
    case Bonfire.Social.Pins.list_instance_pins_activities(
           paginate?: false,
           preload: [:feed_by_subject, :feed_postload]
         ) do
      %{edges: [_ | _] = edges} -> edges
      _ -> []
    end
  end
end
