defmodule Bonfire.UI.Common.SidebarMobileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop name, :string, required: true
  # prop user_image, :string, required: true
  # prop username, :string, required: true
  prop page, :string, required: true
end