defmodule Bonfire.UI.Common.LogoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop with_name, :boolean, default: false

  prop image_class, :css_class, default: nil

  prop name_class, :css_class, default: nil

  @doc "Whether the instance shows a small logo plus its name at the top of the sidebar, instead of the large square logo."
  def compact_sidebar_logo? do
    to_string(Bonfire.Common.Settings.get([:ui, :sidebar, :logo_style], "large", :instance)) ==
      "compact"
  end
end
