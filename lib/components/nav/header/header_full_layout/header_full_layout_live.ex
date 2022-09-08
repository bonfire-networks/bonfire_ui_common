defmodule Bonfire.UI.Common.HeaderFullLayoutLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.BadgeCounterLive

  prop page, :string
  prop user, :map
  prop page_title, :string
  prop page_header_drawer, :boolean 
  prop page_header_aside, :any
  # need to pass down props for SmartInput:
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :atom, default: nil
  prop showing_within, :any, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: nil
  prop hide_smart_input, :boolean, default: false
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop sidebar_widgets, :list, default: []
  prop thread_mode, :atom, default: nil
  prop show_less_menu_items, :boolean, default: false
end
