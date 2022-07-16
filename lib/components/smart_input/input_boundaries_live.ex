defmodule Bonfire.UI.Common.InputBoundariesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop create_activity_type, :any
  prop preloaded_recipients, :list
  prop to_boundaries, :list
  prop to_circles, :list
  prop showing_within, :any
  prop show_select_recipients, :boolean, default: false
  prop open_boundaries, :boolean, default: false
  prop thread_mode, :string

end
