defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  prop component, :any, default: nil
  prop icon, :any, default: nil
end
