defmodule Bonfire.UI.Common.MobileSmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  # prop create_object_type, :atom, default: nil
end
