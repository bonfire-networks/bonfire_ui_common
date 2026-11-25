defmodule Bonfire.UI.Common.LogoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop with_name, :boolean, default: false

  prop image_class, :css_class, default: nil

  prop name_class, :css_class, default: nil

  @doc "The instance banner to show in place of the icon, or nil when that setting is off or no banner is set"
  def banner_as_icon do
    if Config.get([:ui, :theme, :banner_as_icon], false),
      do: Bonfire.UI.Common.GuestBoardLive.banner_image()
  end
end
