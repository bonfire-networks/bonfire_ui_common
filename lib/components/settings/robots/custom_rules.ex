defmodule Bonfire.UI.Common.CrawlerBoundaries.CustomRules do
  use Bonfire.UI.Common.Web, :stateless_component

  prop settings, :map, required: true
  prop on_update_setting, :event, required: true
end
