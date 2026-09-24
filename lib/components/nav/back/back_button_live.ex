defmodule Bonfire.UI.Common.BackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop type, :any, default: nil
  prop back, :any, default: nil
  prop icon, :string, default: "carbon:chevron-left"
  prop icon_class, :css_class, default: "w-4 h-4"
  prop class, :css_class, default: "btn btn-xs btn-circle z-50 btn-ghost"
end
