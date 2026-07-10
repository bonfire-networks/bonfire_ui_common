defmodule Bonfire.UI.Common.ImpressumLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop links, :list, default: nil

  def powered_by_name do
    Config.get([:ui, :theme, :powered_by, :name]) || Bonfire.Application.name_and_flavour()
  end

  def powered_by_url do
    Config.get([:ui, :theme, :powered_by, :url]) || "https://bonfirenetworks.org/"
  end
end
