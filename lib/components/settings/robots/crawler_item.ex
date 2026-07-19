defmodule Bonfire.UI.Common.CrawlerBoundaries.CrawlerItem do
  use Bonfire.UI.Common.Web, :stateless_component

  prop crawler, :map, required: true
  prop blocked?, :boolean, required: true
  prop disabled?, :boolean, default: false
  prop on_toggle_crawler, :event, required: true
end
