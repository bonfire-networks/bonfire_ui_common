defmodule Bonfire.UI.Common.Empty do
  use Bonfire.UI.Common.Web, :stateless_component

  prop comment, :any, default: nil

  slot default
end
