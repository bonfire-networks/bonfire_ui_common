defmodule Bonfire.UI.Common.SidebarNavigationLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string, required: true
  prop smart_input_prompt, :string
end
