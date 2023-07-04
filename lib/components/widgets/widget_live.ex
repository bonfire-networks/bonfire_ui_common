defmodule Bonfire.UI.Common.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget, :any, required: true
  prop data, :any, default: []
  prop without_icon, :boolean, default: false

  prop text_class, :css_class,
    required: false,
    default: "text-[18px] font-normal text-base-content flex-1"

  prop icon_class, :css_class, required: false, default: "w-6 h-6 text-base-content"
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop wrapper_class, :css_class, default: "m-0 p-0 rounded-md !block"
  prop showing_within, :atom, default: :sidebar

  def widget(%{name: :extension, app: app}, _context) do
    Bonfire.Common.ExtensionModule.extension(app)
  end

  def widget(%{name: :current_extension}, context) do
    context[:current_extension]
  end

  def widget(widget, _context) do
    widget
  end
end
