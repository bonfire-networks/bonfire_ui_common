defmodule Bonfire.UI.Common.ExtensionsDetailsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop scope, :any, default: nil
  prop is_extension?, :boolean, default: false
  prop can_instance_wide, :boolean, default: nil
  prop required_dep?, :boolean, default: false
  prop dep, :any, default: nil
end
