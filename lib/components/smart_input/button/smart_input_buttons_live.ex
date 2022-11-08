defmodule Bonfire.UI.Common.SmartInputButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.SmartInputButtonLive

  prop smart_input_prompt, :string, required: false
  prop smart_input_component, :atom, default: nil
  prop create_object_type, :any, default: nil
  prop smart_input_as, :any, default: nil
  prop class, :css_class, default: "hidden w-[40px] gap-2 tablet-lg:w-full tablet-lg:rounded tablet-lg:flex h-[40px] items-center tablet-lg:px-3 normal-case btn-circle btn-sm btn btn-primary"
end
