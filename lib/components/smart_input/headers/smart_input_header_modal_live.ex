defmodule Bonfire.UI.Common.SmartInputHeaderModalLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop smart_input_opts, :map, default: %{}
  prop create_object_type, :atom
end
