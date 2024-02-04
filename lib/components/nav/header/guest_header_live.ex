defmodule Bonfire.UI.Common.GuestHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop selected_tab, :atom, default: nil
  prop page, :string, default: "home"
end
