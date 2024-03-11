defmodule Bonfire.UI.Common.BackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop close_preview, :any, default: nil
  prop back, :any, default: true
end
