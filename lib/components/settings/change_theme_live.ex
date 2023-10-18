defmodule Bonfire.UI.Common.ChangeThemeLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop label, :string, default: nil
  prop key, :string, default: "instance_theme"
  prop theme, :string
  prop themes, :list

  prop scope, :any, default: nil
end
