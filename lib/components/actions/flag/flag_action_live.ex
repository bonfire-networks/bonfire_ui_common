defmodule Bonfire.UI.Common.FlagActionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop label, :string, default: nil
  prop flagged, :any, default: nil
end
