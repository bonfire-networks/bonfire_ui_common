defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler
  prop smart_input_opts, :map, default: %{}

  prop component, :any, default: nil
  prop create_object_type, :any, default: nil

  prop icon, :any, default: nil
  prop prompt, :any, default: nil

  prop showing_within, :atom, default: nil

  prop class, :css_class,
    default:
      "fixed right-3 bottom-[72px] btn btn-sm w-full rounded btn-primary flex items-center gap-2 normal-case"
end
