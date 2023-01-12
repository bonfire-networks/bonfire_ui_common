defmodule Bonfire.UI.Common.SidebarSettingsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string
  prop selected_tab, :string
  prop id, :string, default: nil

  declare_nav_component("Links to sections of settings")
  # exclude_from_nav: true
end
