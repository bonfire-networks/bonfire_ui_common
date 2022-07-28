defmodule Bonfire.UI.Common.NavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # Note: if NavLive is embedded is in a non-Surface component, these default props are ignore, see defaults set in `Bonfire.UI.Common.LayoutLive` instead
  prop page_title, :string, default: nil
  prop page, :any, default: nil
  prop page_header_aside, :list, default: nil
  prop page_header_drawer, :boolean, default: false
  prop inner_content, :any, default: nil
  prop reply_to_id, :string, default: nil
  prop thread_id, :string, default: nil
  prop create_activity_type, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: []
  prop smart_input_prompt, :string, default: nil
  prop smart_input_text, :string, default: nil
  prop showing_within, :any, default: nil
  prop without_sidebar, :boolean, default: false
  prop sidebar_widgets, :list, default: []
  prop hide_smart_input, :boolean, default: false
  prop thread_mode,  :string, default: nil
  prop show_less_menu_items, :boolean, default: false

end
