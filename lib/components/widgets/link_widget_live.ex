defmodule Bonfire.UI.Common.LinkWidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop href, :string, default: nil
  prop text, :string, default: nil
  prop icon, :string, default: nil

  prop widget, :any, default: %{}
  prop without_icon, :boolean, default: false
  prop without_label, :boolean, default: false

  prop text_class, :css_class,
    required: false,
    default: nil

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar

  prop wrapper_class, :css_class, default: "m-0 p-0 justify-end rounded-full !block"
  prop link_class, :any, default: nil
  prop icon_class, :css_class, required: false, default: "w-6 h-6 text-base-content/80"

  prop skip_badges, :any, default: false
end
