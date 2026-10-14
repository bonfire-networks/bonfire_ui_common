defmodule Bonfire.UI.Common.LogoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop with_name, :boolean, default: false

  prop image_class, :css_class, default: nil

  prop name_class, :css_class, default: nil
end
