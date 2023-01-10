defmodule Bonfire.UI.Common.ExtensionsSidebarSettingsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string, default: nil
  prop selected_tab, :string
  prop scope, :atom, default: nil

  declare_nav_component("Links to sections of settings")
  # exclude_from_nav: true
end
