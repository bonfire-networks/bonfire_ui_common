defmodule Bonfire.UI.Common.BackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop showing_within, :atom, default: nil
  prop back, :any, default: true
end
