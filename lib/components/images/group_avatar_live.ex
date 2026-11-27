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

  @doc "Lazy-load the uploaded image (in lists)."
  prop lazy, :boolean, default: false

  @doc "For a group marked sensitive: the DOM id of the blur overlay put over the uploaded image (which gets `data-sensitive`), hidden by `Bonfire.Classify.Web.CategoryLive.show_sensitive/2`. The caller's box around it must be `relative`. Nil for none."
  prop sensitive_id, :string, default: nil

  @doc "Shown in place of the tile when there is no uploaded image, for a card that keeps its own placeholder."
  slot default
end
