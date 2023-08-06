defmodule Bonfire.UI.Common.LazyImage do
  use Bonfire.UI.Common.Web, :stateless_component

  prop parent_id, :string, default: nil
  prop media, :any, default: nil
  prop src, :string, default: nil
  prop alt, :string, default: nil
  prop class, :css_class, default: nil
  prop fallback_icon, :string, default: Icon.icon_name("circum:image-off")
  prop opts, :any, default: %{}
  prop title, :string, default: ""
end
