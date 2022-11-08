defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  prop component, :any, default: nil
  prop icon, :any, default: nil
  prop class, :css_class, default: "hidden w-[40px] gap-2 tablet-lg:w-full tablet-lg:rounded tablet-lg:flex h-[40px] items-center tablet-lg:px-3 normal-case btn-circle btn-sm btn btn-primary"
end
