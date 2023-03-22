defmodule Bonfire.UI.Common.SmartInputButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.SmartInputButtonLive
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop smart_input_opts, :map, default: %{}
  prop smart_input_component, :atom, default: nil
  prop create_object_type, :any, default: nil
  # prop smart_input_opts, :map, default: %{}

  prop class, :css_class,
    default:
      "fixed right-3 md:static bottom-[72px] flex-1 btn text-sm md:w-auto btn-square h-[64px] w-[64px] md:h-[38px] md:min-h-[38px] md:max-h-[38px] bg-base-content/90 text-base-100/90 md:bg-primary md:text-primary-content md:btn-primary rounded-xl md:rounded shadow flex items-center gap-2 normal-case"
end
