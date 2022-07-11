defmodule Bonfire.UI.Common.FlagActionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop label, :string
  prop my_flag, :any
  prop class, :css_class

end
