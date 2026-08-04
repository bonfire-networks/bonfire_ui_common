defmodule Bonfire.UI.Common.SmartInputButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop smart_input_opts, :map, default: %{}

  prop id, :any, default: nil
  prop component, :any, default: nil
  prop as_icon, :boolean, default: false
  prop without_icon, :boolean, default: false
  prop icon, :any, default: nil
  prop icon_class, :css_class, default: ""
  prop prompt, :any, default: nil
  # prop text_suggestion, :any, default: nil

  prop showing_within, :atom, default: nil

  prop class, :css_class,
    default:
      "flex-row grow md:h-[40px] items-center normal-case gap-2 md:btn-sm btn btn-primary hover:scale-[1.02] active:scale-[0.97]"
end
