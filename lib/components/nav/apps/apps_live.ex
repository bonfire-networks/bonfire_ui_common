defmodule Bonfire.UI.Common.AppsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop current_extension, :any, default: %{}
end
