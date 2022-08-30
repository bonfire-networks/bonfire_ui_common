defmodule Bonfire.UI.Common.SmartInputHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  prop smart_input_component, :atom, default: nil
  prop create_activity_type, :atom, default: nil


end
