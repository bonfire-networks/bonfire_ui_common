defmodule Bonfire.UI.Common.ProfileNavigationLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string, default: nil
  prop path_prefix, :string, required: true
  prop tabs, :list, required: true
end
