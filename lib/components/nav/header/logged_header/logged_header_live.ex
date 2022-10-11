defmodule Bonfire.UI.Common.LoggedHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, default: nil
  prop page, :string, default: nil
  prop page_header_drawer, :boolean, default: false
  prop page_header_aside, :any, default: nil
  prop custom_page_header, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop showing_within, :any, default: nil
  prop reply_to_id, :string, default: nil
  prop without_sidebar, :boolean, default: false
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop thread_mode, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: []
  prop smart_input_as, :atom, default: nil
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop sidebar_widgets, :list, default: []

  prop selected_tab, :any, default: nil
  prop nav_items, :list, default: []
end
