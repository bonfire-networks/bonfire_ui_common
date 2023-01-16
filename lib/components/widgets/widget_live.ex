defmodule Bonfire.UI.Common.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget, :any, required: true
  prop data, :any, default: []
  prop without_icon, :boolean, default: false

  prop text_class, :css_class,
    required: false,
    default: "text-sm font-normal text-base-content/80"

  prop icon_class, :css_class, required: false, default: "w-[22px] h-[22px] text-base-content/80"
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop wrapper_class, :css_class, default: "m-0 p-0 rounded-md"
  prop showing_within, :atom, default: :sidebar
  
  def widget(%{name: :extension, app: app}, context) do
    Bonfire.Common.ExtensionModule.extension(app)
  end

  def widget(%{name: :current_extension}, context) do
    context[:current_extension]
  end

  def widget(widget, _context) do
    widget
  end
end
