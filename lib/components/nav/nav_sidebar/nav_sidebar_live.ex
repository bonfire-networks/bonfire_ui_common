defmodule Bonfire.UI.Common.NavSidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Me.Users

  prop sidebar_widgets, :list, default: []
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop nav_items, :list, default: []
  prop csrf_token, :any, default: nil
  prop current_user_id, :any, default: nil
  prop current_account_id, :any, default: nil
  prop exclude_circles, :list, default: []
end
