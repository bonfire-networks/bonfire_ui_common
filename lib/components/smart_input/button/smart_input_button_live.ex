defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop smart_input_opts, :map, default: %{}

  prop component, :any, default: nil
  prop create_object_type, :any, default: nil
  prop as_icon, :boolean, default: false
  prop icon, :any, default: nil
  prop prompt, :any, default: nil

  prop showing_within, :atom, default: nil

  prop class, :css_class,
    default:
      "flex-row btn-square grow md:h-[40px] items-center normal-case gap-2 md:btn-sm btn btn-primary"
end
