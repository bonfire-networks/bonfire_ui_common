defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  prop component, :any, default: nil
  prop icon, :any, default: nil

  prop class, :css_class,
    default:
      "hidden w-full h-[40px] md:flex items-center  normal-case  gap-2 btn-sm btn btn-primary"
end
