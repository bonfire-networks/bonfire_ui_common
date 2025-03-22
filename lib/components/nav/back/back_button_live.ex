defmodule Bonfire.UI.Common.BackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop type, :any, default: nil
  prop back, :any, default: nil
end
