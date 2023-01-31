defmodule Bonfire.UI.Common.ChangeThemesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop theme, :string
  prop theme_light, :string
  prop scope, :any, default: nil
  prop scoped, :any, default: nil
end
