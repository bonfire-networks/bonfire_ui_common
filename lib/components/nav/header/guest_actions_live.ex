defmodule Bonfire.UI.Common.GuestActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop page_header, :boolean, default: false
  prop page, :any, default: nil
end
