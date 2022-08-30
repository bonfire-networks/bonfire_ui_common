defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  prop smart_input_component, :atom, default: nil
  prop create_activity_type, :atom, default: nil
  prop smart_input_as, :atom, default: :sidebar

end
