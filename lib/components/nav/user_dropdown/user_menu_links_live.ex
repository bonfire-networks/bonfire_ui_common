defmodule Bonfire.UI.Common.UserMenuLinksLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Me.Integration

  alias Surface.Components.LiveRedirect
  prop mobile, :boolean, default: false
  # prop name, type, options
  # prop user_image, :string, required: true
  # prop name, :string, required: true
  # prop username, :string, required: true
end
