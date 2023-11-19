defmodule Bonfire.UI.Common.UserMenuLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # prop name, type, options
  # prop user_image, :string, required: true
  prop page, :any, default: nil
  # prop username, :string, required: true
end
