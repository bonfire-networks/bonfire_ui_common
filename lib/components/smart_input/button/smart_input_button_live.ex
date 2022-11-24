defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_opts, :any, default: []
  prop component, :any, default: nil
  prop icon, :any, default: nil

  prop class, :css_class, default: nil
end
