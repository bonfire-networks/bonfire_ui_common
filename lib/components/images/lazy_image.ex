defmodule Bonfire.UI.Common.LazyImage do
  use Bonfire.UI.Common.Web, :stateless_component

  prop src, :string
  prop class, :string
  prop alt, :string
  prop opts, :list


end
