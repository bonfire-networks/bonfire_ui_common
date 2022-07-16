defmodule Bonfire.UI.Common.NavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :any
  prop page_title, :string
  prop page_header_aside, :any
  prop page_header_drawer, :boolean
  prop inner_content, :any
  # need to pass down props for SmartInput:
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :any
  prop to_boundaries, :list, default: []
  prop to_circles, :list
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop showing_within, :any
  prop without_sidebar, :boolean, required: false, default: nil
  prop sidebar_widgets, :list, default: []
  prop hide_smart_input, :boolean, default: false
  prop thread_mode,  :string
end
