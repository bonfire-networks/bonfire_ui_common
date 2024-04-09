defmodule Bonfire.UI.Common.ThemePreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop custom_styles, :any, default: ""
  prop theme, :string, default: "light"
end
