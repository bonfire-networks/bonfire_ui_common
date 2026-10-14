defmodule Bonfire.UI.Common.WidgetsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :any, default: nil

  prop widgets, :any, required: true
  prop with_title, :boolean, default: false
  prop with_description, :boolean, default: false
  prop compact, :boolean, default: false
  prop type, :any, default: nil
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar

  prop extra_data, :any, default: %{}

  @doc "Whether the list can be reordered by dragging."
  prop reorderable, :boolean, default: true
  @doc "Whether to apply the user's saved order (off = always the default order)."
  prop use_saved_order, :boolean, default: true

  prop container_class, :css_class, default: nil
  prop wrapper_class, :css_class, default: nil
  @doc "Classes for each `:link` widget's anchor (e.g. `nav-row`)."
  prop link_class, :any, default: ""
  @doc "Size classes for each `:link` widget's icon (its colour follows the active state)."
  prop icon_class, :css_class, default: "size-5"

  @doc """
  The key a widget's saved position is stored under: its `page`, or else its module.

      iex> Bonfire.UI.Common.WidgetsLive.order_key(%{page: "home", module: Some.Widget})
      "home"

      iex> Bonfire.UI.Common.WidgetsLive.order_key({Some.Widget, []})
      Some.Widget
  """
  def order_key(%{} = widget), do: widget[:page] || widget[:module]
  def order_key({module, _data}) when is_atom(module), do: module
  def order_key(_), do: nil

  @doc """
  Sorts items by a saved order (`%{key => position}`), returning `{item, default_index}` tuples. Items not in the saved order go last, in default order.

      iex> Bonfire.UI.Common.WidgetsLive.sort_by_saved_order([:a, :b, :c], %{c: 0, a: 1}, & &1)
      [{:c, 2}, {:a, 0}, {:b, 1}]

      iex> Bonfire.UI.Common.WidgetsLive.sort_by_saved_order([:a, :b], nil, & &1)
      [{:a, 0}, {:b, 1}]
  """
  def sort_by_saved_order(items, order, key_fun) do
    items
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.sort_by(fn {item, index} ->
      case key_fun.(item) do
        nil ->
          {1, index}

        key ->
          case e(order, Bonfire.Common.Types.maybe_to_atom(key), nil) do
            position when is_integer(position) -> {0, position}
            _ -> {1, index}
          end
      end
    end)
  end

  @doc """
  Sorts `items` by the user's order saved under `[:ui, setting, list_key]`, returning `{item, default_index}` tuples. With `use_saved_order?` false, keeps the default order.
  """
  def ordered(items, setting, list_key, use_saved_order?, context)

  def ordered(items, _setting, _list_key, false, _context),
    do: sort_by_saved_order(items, nil, &order_key/1)

  def ordered(items, setting, list_key, _, context) do
    order =
      Bonfire.Common.Settings.get([:ui, setting], [], current_user: current_user(context))
      |> ed(list_key, nil)

    sort_by_saved_order(items, order, &order_key/1)
  end
end
