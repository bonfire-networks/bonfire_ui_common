defmodule Bonfire.UI.Common.CrawlerBoundaries.ActionButtons do
  use Bonfire.UI.Common.Web, :stateless_component

  prop on_test, :event, required: true
  prop on_reset, :event, required: true
end
