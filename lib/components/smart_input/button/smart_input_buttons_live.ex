defmodule Bonfire.UI.Common.SmartInputButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.SmartInputButtonLive

  prop smart_input_opts, :map, default: %{}
  prop smart_input_component, :atom, default: nil
  prop create_object_type, :any, default: nil
  # prop smart_input_opts, :map, default: %{}

  prop class, :css_class,
    default:
      "fixed right-3 md:static bottom-[72px] btn text-sm md:w-full btn-square md:h-[42px] md:min-h-[42px] md:max-h-[42px] btn-primary rounded-2xl md:rounded flex items-center gap-2 normal-case"
end
