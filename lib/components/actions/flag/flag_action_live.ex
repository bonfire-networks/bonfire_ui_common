defmodule Bonfire.UI.Common.FlagActionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop label, :string, default: nil
  prop my_flag, :any, default: nil
  # prop class, :css_class, default: nil
end
