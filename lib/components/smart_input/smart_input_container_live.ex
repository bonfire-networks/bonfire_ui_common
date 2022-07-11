defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :any
  prop smart_input_component, :atom
  prop to_boundaries, :list
  prop to_circles, :list
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop showing_within, :any
  prop with_rich_editor, :boolean, required: false
  prop activity, :any
  prop hide_smart_input, :boolean, default: false
  prop object, :any
  prop activity_inception, :any
  prop preset_boundary, :any, default: "public"
  prop title_open, :boolean, default: false
  prop title_prompt, :string
  prop preloaded_recipients, :list
  prop show_select_recipients, :boolean, default: false
  prop thread_mode, :string

end
