defmodule Bonfire.UI.Common.ExtensionsSidebarSettingsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string, default: nil
  prop showing_within, :atom, default: nil
  prop selected_tab, :any, default: nil
  prop id, :any, default: nil
  prop scope, :any, default: nil

  declare_nav_component("Links to sections of settings")
  # exclude_from_nav: true
end
