defmodule Bonfire.UI.Common.LogoLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop href, :string, default: nil
  prop with_name, :boolean, default: false

  prop container_class, :css_class, default: "flex items-center gap-2"

  prop image_class, :css_class, default: nil

  prop name_class, :css_class, default: nil

  slot default
end
