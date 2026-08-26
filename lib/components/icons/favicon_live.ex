defmodule Bonfire.UI.Common.Icons.FaviconLive do
  @moduledoc """
  The favicon for a URL, falling back to `icon` when we have none cached (or when the cached one fails to load). The lookup is non-blocking: `FaviconStore` returns either a cached path or a controller URL that fetches it in the background.

  Used on its own, and by `Bonfire.UI.Common.Icons.InstanceIconLive` which adds the link and
  tooltip around it.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop link, :string, default: nil
  prop icon, :string, default: "ph:planet-fill"
  prop class, :css_class, default: "w-4 h-4"
end
