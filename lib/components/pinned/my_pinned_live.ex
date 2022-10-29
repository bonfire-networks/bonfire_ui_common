defmodule Bonfire.UI.Common.MyPinnedLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string, default: nil
  prop object_types, :any, default: []
end
