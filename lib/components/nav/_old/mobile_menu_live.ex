defmodule Bonfire.UI.Common.MobileMenuLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop sidebar_widgets, :list, default: []
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop nav_items, :any, default: nil

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop show_select_recipients, :boolean, default: false
  prop thread_mode, :atom, default: nil
  prop without_sidebar, :string, default: nil
end
