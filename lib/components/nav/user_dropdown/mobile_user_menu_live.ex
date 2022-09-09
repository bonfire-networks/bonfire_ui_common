defmodule Bonfire.UI.Common.MobileUserMenuLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Surface.Components.LivePatch
  # prop name, type, options
  # prop user_image, :string, required: true
  # prop name, :string, required: true
  # prop username, :string, required: true

  prop page, :string, default: ""
  
end
