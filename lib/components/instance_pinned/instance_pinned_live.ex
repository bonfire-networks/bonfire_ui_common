defmodule Bonfire.UI.Common.InstancePinnedLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string, default: nil
  prop object_types, :any, default: []
  prop load_pointer, :boolean, default: false
end
