defmodule Bonfire.UI.Common.CrawlerBoundaries.ConfigForm do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.CrawlerBoundaries

  alias Bonfire.UI.Common.CrawlerBoundaries.{
    CrawlerCategoryList,
    CustomRules,
    BlockingSettings,
    ActionButtons
  }

  prop id, :string, required: true
  prop settings, :map, required: true
  prop scope, :any, default: nil
  prop show_advanced, :boolean, default: false

  prop on_update_setting, :event, required: true
  prop on_toggle_category, :event, required: true
  prop on_toggle_crawler, :event, required: true
  prop on_test, :event, required: true
  prop on_reset, :event, required: true
  prop on_toggle_advanced, :event, required: true
end
