defmodule Bonfire.UI.Common.ExtensionsDetailsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop scope, :any, default: nil
  prop hide_icon, :boolean, default: nil
  prop can_instance_wide, :boolean, default: nil
  prop required_deps, :list, default: []
end
