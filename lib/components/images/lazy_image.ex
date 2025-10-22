defmodule Bonfire.UI.Common.LazyImage do
  use Bonfire.UI.Common.Web, :stateless_component

  prop parent_id, :string, default: nil
  prop media, :any, default: nil
  prop src, :string, default: nil
  prop alt, :string, default: nil
  prop class, :css_class, default: nil
  prop fallback_class, :css_class, default: "w-5 h-5 opacity-50"
  prop fallback_icon, :string, default: Icon.icon_name("ph:image-broken-duotone")
  prop opts, :any, default: %{}
  prop title, :string, default: ""
  prop disable_lazy, :boolean, default: true
end
