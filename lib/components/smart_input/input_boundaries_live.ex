defmodule Bonfire.UI.Common.InputBoundariesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop create_activity_type, :any
  prop to_boundaries, :list
  prop to_circles, :list
  prop showing_within, :any
  prop show_select_recipients, :boolean, default: false
  prop open_boundaries, :boolean, default: false

  def default_boundaries(%{to_boundaries: to_boundaries}) when is_list(to_boundaries) and length(to_boundaries)>0 do
    to_boundaries
  end

  def default_boundaries(_assigns) do
    # TODO: configurable
    [{l("Public"), "public"}]
  end

end
