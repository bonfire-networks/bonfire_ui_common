defmodule Bonfire.UI.Common.ComposerCloseLive do
  @moduledoc "The composer's close (✕): with a draft it asks \"Discard draft?\", without one it closes and resets the options (`close_empty`). Rendered in the header and in the phone top bar; `id_prefix` keeps their ids apart."
  use Bonfire.UI.Common.Web, :stateless_component

  prop input_status, :any, default: nil
  prop id_prefix, :string, default: ""
  prop btn_class, :css_class, default: nil
  prop icon_class, :css_class, default: "size-4"
end
