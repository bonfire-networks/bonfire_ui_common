defmodule Bonfire.UI.Common.CrawlerBoundaries.PreviewPanel do
  use Bonfire.UI.Common.Web, :stateless_component

  prop robots_txt_preview, :string, required: true
end
