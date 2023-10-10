defmodule Bonfire.UI.Common.LogoLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop href, :any, default: nil
  prop with_name, :boolean, default: false

  prop container_class, :css_class, default: "flex items-center gap-4"

  prop image_class, :css_class, default: "w-10 h-10 bg-center bg-no-repeat bg-contain"

  prop name_class, :css_class, default: "text-xl font-bold text-base-content tablet-lg:block hidden"

  slot default
end
