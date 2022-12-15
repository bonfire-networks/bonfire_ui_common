defmodule Bonfire.UI.Common.SmartInputButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.SmartInputButtonLive

  prop smart_input_opts, :any, default: []
  prop smart_input_component, :atom, default: nil
  prop create_object_type, :any, default: nil
  # prop smart_input_opts, :any, default: []

  prop class, :css_class,
    default: "btn w-full h-[42px] min-h-[42px] max-h-[42px] btn-primary rounded flex items-center gap-2 normal-case"
end
