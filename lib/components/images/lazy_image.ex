defmodule Bonfire.UI.Common.LazyImage do
  use Bonfire.UI.Common.Web, :stateless_component

  prop src, :string
  prop class, :css_class, default: nil
  prop alt, :string
  prop opts, :any, default: %{}
end
