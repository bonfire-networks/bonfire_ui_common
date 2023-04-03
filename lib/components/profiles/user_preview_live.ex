defmodule Bonfire.UI.Common.UserPreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Utils
  # import Bonfire.Common.Media

  prop user, :map
  prop path_prefix, :string, default: "/@"
  prop go, :string, default: nil

  slot actions, required: false
end
