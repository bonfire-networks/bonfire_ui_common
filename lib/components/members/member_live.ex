defmodule Bonfire.UI.Common.MemberLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map, required: true
  prop counter, :string, default: 0
end
