defmodule Bonfire.UI.Common.LogoLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop href, :any, default: nil
  prop with_name, :boolean, default: false

  prop container_class, :css_class,
    default: "flex place-content-center items-center gap-4 cursor-pointer"

  prop image_class, :css_class,
    default:
      "w-8 h-8 aspect-square rounded-full border border-base-content/10 bg-center bg-no-repeat bg-contain"

  prop name_class, :css_class, default: "text-xl font-bold text-base-content lg:block hidden"

  prop link_opts, :list, default: []
  slot default
end
