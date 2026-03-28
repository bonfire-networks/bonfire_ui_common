defmodule Bonfire.UI.Common.CrawlerBoundaries.BlockingSettings do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.CrawlerBoundaries.AdvancedSettings

  prop settings, :map, required: true
  prop show_advanced, :boolean, required: true
  prop on_update_setting, :event, required: true
  prop on_toggle_advanced, :event, required: true
end
