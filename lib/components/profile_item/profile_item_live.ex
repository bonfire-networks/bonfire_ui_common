defmodule Bonfire.UI.Common.ProfileItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any
  prop character, :any
  prop class, :css_class
  prop show_controls, :list, default: [:follow]

  slot default, required: false
end
