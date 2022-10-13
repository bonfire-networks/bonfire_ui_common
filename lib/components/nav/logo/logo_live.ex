defmodule Bonfire.UI.Common.LogoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop with_name, :boolean, default: false

  prop image_class, :css_class, default: "w-8 h-8 bg-center bg-no-repeat bg-contain"

  prop name_class, :css_class, default: "text-lg font-bold text-base-content"
end
