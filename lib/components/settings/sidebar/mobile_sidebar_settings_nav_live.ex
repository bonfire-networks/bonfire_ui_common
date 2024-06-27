defmodule Bonfire.UI.Common.MobileSidebarSettingsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop id, :string, default: nil
  prop showing_within, :atom, default: :settings
end
