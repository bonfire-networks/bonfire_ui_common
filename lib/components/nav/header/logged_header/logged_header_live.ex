defmodule Bonfire.UI.Common.LoggedHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, default: nil
  prop page, :string, default: nil
  prop page_header_drawer, :boolean, default: false
  prop page_header_aside, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop showing_within, :any, default: nil
  prop reply_to_id, :string, default: ""
  prop without_sidebar, :boolean, default: false
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :atom, default: nil
  prop thread_mode, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: nil
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  
end
