defmodule Bonfire.UI.Common.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget, :any, required: true
  prop data, :any, default: []
  prop without_icon, :boolean, default: false
  prop without_label, :boolean, default: false

  prop text_class, :css_class,
    required: false,
    default: nil

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar

  prop wrapper_class, :css_class, default: "m-0 p-0 rounded-md !block"
  prop link_class, :any, default: nil
  prop icon_class, :css_class, required: false, default: "w-7 h-7 text-base-content"

  def render(assigns) do
    assigns
    |> assign(:widget, widget(assigns[:widget], assigns[:__context__]))
    |> render_sface()
  end

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
