defmodule Bonfire.UI.Common.SettingsViewLive.SidebarSettingsMobileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop page, :string
  prop id, :string, default: nil
end
