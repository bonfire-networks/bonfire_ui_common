defmodule Bonfire.UI.Common.SelectRecipientsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop target_component, :string
  prop preloaded_recipients, :list, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: []
  prop showing_within, :any, default: nil
end
