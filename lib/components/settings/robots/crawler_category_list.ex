defmodule Bonfire.UI.Common.CrawlerBoundaries.CrawlerCategoryList do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.CrawlerBoundaries
  alias Bonfire.UI.Common.CrawlerBoundaries.CrawlerCategory

  prop settings, :map, required: true
  prop on_toggle_category, :event, required: true
  prop on_toggle_crawler, :event, required: true
end
