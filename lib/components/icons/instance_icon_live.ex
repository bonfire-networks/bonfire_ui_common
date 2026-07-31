defmodule Bonfire.UI.Common.Icons.InstanceIconLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop peered, :any, default: nil

  prop link_opts, :list, default: []
end
