defmodule Bonfire.UI.Common.GroupAvatarLive do
  @moduledoc "A group's or topic's avatar: the image it uploaded, else the icon it picked (in its colour), else its initial. See `Bonfire.UI.Common.NavTileLive.uploaded_avatar_url/1` for the choice, and `Bonfire.UI.Common.NavTileLive` for the icon and the initial."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The group or topic (with its `:profile`, and its `:settings` for the picked icon and colour)."
  prop object, :any, required: true

  @doc "Its name, for the initial."
  prop name, :string, default: nil

  @doc "The size of the uploaded image, in px."
  prop size, :integer, default: 56

  @doc "Classes of the uploaded image."
  prop image_class, :css_class, default: nil

  @doc "Classes of the tile, to size it like the image (the tile's own size classes need `!`)."
  prop tile_class, :css_class, default: nil
end
