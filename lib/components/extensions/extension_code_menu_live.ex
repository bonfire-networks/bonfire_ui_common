defmodule Bonfire.UI.Common.ExtensionCodeMenuLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  # prop scope, :atom, default: nil
  prop dep, :map, default: nil
end
