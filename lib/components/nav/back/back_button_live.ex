defmodule Bonfire.UI.Common.BackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop type, :any, default: nil
  prop back, :any, default: nil
  prop class, :css_class, default: "btn btn-xs btn-circle z-50 btn-outline border-secondary"
end
