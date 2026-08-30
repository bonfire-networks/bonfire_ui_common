defmodule Bonfire.UI.Common.CrawlerBoundaries.CrawlerCategory do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.CrawlerBoundaries
  alias Bonfire.UI.Common.CrawlerBoundaries.CrawlerItem

  prop category, :string, required: true
  prop category_info, :map, required: true
  prop crawlers, :list, required: true
  prop settings, :map, required: true
  prop on_toggle_category, :event, required: true
  prop on_toggle_crawler, :event, required: true
end
