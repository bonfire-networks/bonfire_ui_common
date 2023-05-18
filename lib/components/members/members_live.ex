defmodule Bonfire.UI.Common.MembersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil
  prop users, :list, required: true
end
