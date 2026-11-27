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

  @doc "The page whose widgets get edit mode, see `Bonfire.UI.Common.Widgets.place_assigns/4`."
  prop editable, :any, default: nil

  @doc "Renders only edit mode's tiles, not the widgets' content, see `Bonfire.UI.Common.WidgetLive`."
  prop tiles_only, :boolean, default: false
  @doc "The tiles' settings at `:instance` scope, else the viewer's own."
  prop scope, :any, default: nil

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
  # `order_id` for widgets that share a module, eg. custom widgets, which are all `WidgetTextLive`
  def order_key(%{} = widget), do: widget[:page] || widget[:order_id] || widget[:module]
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
  Sorts `items` by the order `saved_order/3` finds, returning `{item, default_index}` tuples. With `use_saved_order?` false, keeps the default order.
  """
  def ordered(items, setting, list_key, use_saved_order?, context)

  def ordered(items, _setting, _list_key, false, _context),
    do: sort_by_saved_order(items, nil, &order_key/1)

  def ordered(items, setting, list_key, _, context) do
    user = current_user(context)

    sort_by_saved_order(
      items,
      saved_order(setting, list_key, if(user, do: [current_user: user], else: :instance)),
      &order_key/1
    )
  end

  @doc """
  The order saved under `[:ui, setting, list_key]`, taken whole from one scope: the person's own if they saved one, else the instance's. Never merged across scopes, so a widget the person didn't place can't take the instance's position among theirs. `opts` is `:instance` or `[current_user: user]`.
  """
  def saved_order(setting, list_key, opts) do
    keys = [:ui, setting, Bonfire.Common.Types.maybe_to_atom(list_key)]

    own =
      if opts != :instance,
        do: Bonfire.Common.Settings.get(keys, nil, Keyword.put(opts, :one_scope_only, true))

    own || Bonfire.Common.Settings.get(keys, nil, :instance)
  end
end
