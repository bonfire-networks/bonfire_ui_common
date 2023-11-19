defmodule Bonfire.UI.Common.LoggedActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop page_title, :string, default: nil
  # prop page, :string, default: nil
  # prop page_header_aside, :any, default: nil
  # prop custom_page_header, :any, default: nil
  # prop showing_within, :atom, default: nil
  # prop reply_to_id, :any, default: nil
  # prop context_id, :string, default: nil, required: false
  # prop create_object_type, :any, default: nil
  prop thread_mode, :atom, default: nil
  # prop to_boundaries, :any, default: nil
  # prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop smart_input_opts, :map, default: %{}
  # prop sidebar_widgets, :list, default: []

  # prop selected_tab, :any, default: nil
  # prop nav_items, :list, default: []

  @doc "The page title"
  slot hero
end
