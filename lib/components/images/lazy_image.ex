defmodule Bonfire.UI.Common.LazyImage do
  use Bonfire.UI.Common.Web, :stateless_component

  prop media, :any, default: nil
  prop src, :string, default: nil
  prop alt, :string, default: nil
  prop class, :css_class, default: nil
  prop opts, :any, default: %{}
end
