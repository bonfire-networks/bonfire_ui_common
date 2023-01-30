defmodule Bonfire.UI.Common.ProfileItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any
  prop lg, :boolean, default: false
  prop wrapper_class, :css_class, default: "flex items-center"
  prop character, :any
  prop class, :css_class
  prop show_controls, :list, default: [:follow]
  prop activity_id, :any, default: nil

  slot default, required: false
end
