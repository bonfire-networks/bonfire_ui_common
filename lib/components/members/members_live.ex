defmodule Bonfire.UI.Common.MembersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop users, :list, required: true
end
