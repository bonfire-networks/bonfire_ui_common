defmodule Bonfire.UI.Common.SidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop name, :string, required: true
  # prop user_image, :string, required: true
  # prop username, :string, required: true
  prop page, :string, required: true
  prop layout_mode, :string, required: false, default: nil
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
