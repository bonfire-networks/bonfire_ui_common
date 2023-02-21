defmodule Bonfire.UI.Common.LogoLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop href, :any, default: nil
  prop with_name, :boolean, default: false

  prop container_class, :css_class, default: "flex items-center gap-6"

  prop image_class, :css_class, default: "w-8 h-8 bg-center bg-no-repeat bg-contain"

  prop name_class, :css_class, default: "text-lg font-bold text-base-content"

  slot default
end
