defmodule Bonfire.UI.Common.WidgetAppsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string, default: nil
  prop cols, :integer, default: 3

  prop showing_within, :atom, default: :nav
  prop show_enabled_only, :boolean, default: true
  prop show_disabled_only, :boolean, default: false
end
