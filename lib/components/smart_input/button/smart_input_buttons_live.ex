defmodule Bonfire.UI.Common.SmartInputButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.SmartInputButtonLive

  prop smart_input_prompt, :string, required: false
  prop smart_input_component, :atom, default: nil
  prop create_object_type, :any, default: nil
  prop smart_input_as, :any, default: nil

  prop class, :css_class,
    default: "hidden grow h-[40px] md:flex items-center gap-2 normal-case btn-sm btn btn-primary"
end
