defmodule Bonfire.UI.Common.BackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop type, :any, default: nil
  prop back, :any, default: nil

  @doc "Whether a `back` path is a live patch (the view serving the current page also serves `back`, and keeps its state) rather than a navigate that mounts a new view"
  prop patch, :boolean, default: false
  prop icon, :string, default: "carbon:chevron-left"
  prop icon_class, :css_class, default: "size-4"
  prop class, :css_class, default: "btn btn-xs btn-circle z-50 btn-ghost"
end
