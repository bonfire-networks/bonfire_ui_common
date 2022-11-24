defmodule Bonfire.UI.Common.SmartInputHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_opts, :any, default: []
  prop smart_input_component, :atom, default: nil
  prop create_object_type, :any, default: nil
end
