defmodule Bonfire.UI.Common.SelectRecipientsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils

  # prop target_component, :string
  prop preloaded_recipients, :list
  prop to_circles, :list
  prop showing_within, :any

end
