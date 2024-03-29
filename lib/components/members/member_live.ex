defmodule Bonfire.UI.Common.MemberLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map, required: true
  prop is_local_user, :any, default: nil
  prop counter, :string, default: 0
end
