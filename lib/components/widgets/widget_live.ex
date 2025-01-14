defmodule Bonfire.UI.Common.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget, :any, required: true
  prop data, :any, default: nil
  prop extra_data, :any, default: %{}
  prop without_icon, :boolean, default: false
  prop without_label, :boolean, default: false
  prop with_title, :boolean, default: false
  prop compact, :boolean, default: false
  prop order, :integer, default: nil
  prop is_subwidget, :boolean, default: false

  prop text_class, :css_class,
    required: false,
    default: nil

  prop page, :string, default: nil
  prop parent_id, :string, default: nil
  prop parent_item, :any, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar

  prop wrapper_class, :css_class, default: nil
  prop link_class, :any, default: "!px-0"
  prop icon_class, :css_class, required: false, default: "w-4 h-4 text-base-content"

  prop skip_badges, :any, default: false

  def render(assigns) do
    widget =
      widget(assigns[:widget], assigns[:__context__])
      |> debug("widgg")

    cond do
      widget[:type] == :link ->
        assigns

      module =
          Extend.maybe_module(widget[:module], assigns[:__context__])
          |> debug("!maybe_module #{inspect(widget[:module])}") ->
        data =
          Enum.into(assigns[:data] || e(widget, :data, nil) || [], assigns[:extra_data] || %{})
          |> debug("widdata")

        assigns
        |> assign(
          widget: Map.merge(widget, %{module: module}),
          data: data
        )

      true ->
        debug(widget[:module], "disabled")

        assigns
        |> assign(widget: %{type: :disabled, name: widget[:module]})
    end
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

  # def get_settings_order() do
  #   Bonfire.Common.Settings.get(
  #     [:ui, :widget_order] ++ (if(@parent_item, do: [Types.maybe_to_atom(@parent_item)], else: [])) ++ [Types.maybe_to_atom(@widget[:page])], 
  #     @order, 
  #     current_user(@__context__)
  #   )
  # end
end
