defmodule Bonfire.UI.Common.MembersLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # TODO: move to UI.Me
  prop users, :list, required: true
  prop is_local_users, :any, default: nil
end
