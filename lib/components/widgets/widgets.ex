defmodule Bonfire.UI.Common.Widgets do
  @moduledoc """
  Every widget places can offer: the ones extensions declare (`declare_widget`, see `Bonfire.UI.Common.WidgetModule`), and the custom ones admins write in instance settings.

  A custom widget is stored at instance scope under `[Bonfire.UI.Common.Widgets, :custom, slug]` as `%{title:, text:, width:}`, and offered as `custom_<slug>`, rendered as markdown by `Bonfire.UI.Common.WidgetTextLive`. One without text isn't offered.
  """
  use Bonfire.Common.Utils

  alias Bonfire.Common.Config
  alias Bonfire.Common.Settings
  alias Bonfire.Common.Types
  alias Bonfire.UI.Common.WidgetModule
  alias Bonfire.UI.Common.WidgetsLive

  @doc """
  The widgets a place shows, in order, as the `%{module, data, type}` maps `Bonfire.UI.Common.WidgetsLive` renders (with their `id`).

  A place is `{PlaceModule, key}`, eg. `{Bonfire.Web.Views.DashboardLive, :main}`. See `offered/2`.
  """
  def for_place(place, context) do
    place
    |> offered(context)
    |> Enum.filter(& &1.included)
  end

  @doc """
  A page's widget assigns (main area and sidebar, eg. the dashboard), at mount and after each edit mode change: `main_widgets`, `sidebar_widgets`, `editable_widgets` (the page, for a signed-in viewer), `widgets_addable` (by area) and `widgets_removed` (for Undo).

  With `scope: :instance`, the instance's defaults, for its settings (see `offered/3`). With `for_guests: true`, the widgets guests can see, for a guest page's settings (eg. the homepage): `user` still edits them.
  """
  def place_assigns(place_module, user, removed \\ nil, opts \\ []) do
    editable = if user, do: place_module
    viewer = if opts[:for_guests], do: nil, else: user
    opts = Keyword.take(opts, [:scope])
    main = offered({place_module, :main}, viewer, opts)
    sidebar = offered({place_module, :sidebar}, viewer, opts)
    addable = if editable, do: addable_by_area(main ++ sidebar), else: %{}

    [
      main_widgets: Enum.filter(main, & &1.included),
      sidebar_widgets: [
        users: [secondary: Enum.filter(sidebar, & &1.included)],
        order_key: order_key({place_module, :sidebar}),
        editable: editable,
        addable: addable[:sidebar] || []
      ],
      editable_widgets: editable,
      widgets_addable: addable,
      widgets_removed: removed
    ]
  end

  defp addable_by_area(offered) do
    hidden = Enum.reject(offered, & &1.included)

    Map.new([:main, :sidebar], fn area ->
      {area, Enum.filter(hidden, &(area in [&1.area, &1.move_to]))}
    end)
  end

  @doc """
  Every widget a place can have, in order, each with whether it's `included`:

  - the flavour's defaults come first, in their order (`config <app>, PlaceModule, widgets: [key: [id or {id, props}]]`), then every other widget that fits
  - a page's areas are the keys its flavour config lists (`:main` when it lists none), and a widget sits in exactly one of them: the saved `[PlaceModule, :area, id]`, else the area whose flavour list names it, else the first area its `width` allows (`:wide` is the main area only, `:narrow` a sidebar only, `:any` either)
  - a widget fits when its extension is enabled, it's not `current_user_required` with no viewer, and it has an area on the page; it's offered in that area only
  - it's included when `[PlaceModule, :include, id]` says so, defaulting to whether the flavour lists it in any area of the page, so the instance's choice beats the flavour's and a person's beats the instance's (guests get the instance's)
  - a saved order (`[:ui, :widget_order, order_key(place)]`) beats the default order

  With `scope: :instance`, includes and order are the instance's own values (for its settings), whoever is viewing. The viewer still decides what fits: pass `nil` to list what guests can see.
  """
  def offered({place_module, key} = place, context, opts \\ []) do
    user = current_user(context)

    opts =
      cond do
        opts[:scope] == :instance -> :instance
        user -> [current_user: user]
        true -> :instance
      end

    areas = areas(place_module)
    defaults = default_entries(place)
    default_ids = Enum.map(defaults, &elem(&1, 0))

    # what each area's flavour list names, so a widget moved to another area keeps the props and the on-by-default it was listed with
    listed_in = Map.new(areas, fn area -> {area, default_entries({place_module, area})} end)
    listed_ids = listed_in |> Map.values() |> Enum.concat() |> Enum.map(&elem(&1, 0))

    {listed, others} =
      registry()
      |> Enum.filter(&fits?(&1, user, context))
      |> Enum.filter(&(area_of(&1, place_module, areas, listed_in, opts) == key))
      |> Enum.split_with(&(&1.id in default_ids))

    listed = Enum.sort_by(listed, &Enum.find_index(default_ids, fn id -> id == &1.id end))

    (listed ++ others)
    |> Enum.map(fn widget ->
      %{
        id: widget.id,
        name: widget.name,
        description: widget[:description],
        # a component for the widget's own choice, eg. its feed
        settings: widget[:settings],
        skeleton: widget[:skeleton],
        module: widget.module,
        type: widget.type,
        order_id: widget[:order_id],
        data:
          Keyword.merge(
            List.wrap(widget.props),
            defaults[widget.id] || listed_props(listed_in, widget.id)
          ),
        area: key,
        # the area it moves to, for a widget that fits more than one
        move_to: if(widget.width == :any, do: other_area(key, areas)),
        # whether it's shown when nobody has chosen: the flavour lists it in any area of the page, or the widget says so for this place and viewer
        default: widget.id in listed_ids or included_by_default?(widget.module, place, user),
        included:
          Settings.get(
            [place_module, :include, widget.id],
            widget.id in listed_ids or included_by_default?(widget.module, place, user),
            opts
          ) != false
      }
    end)
    |> WidgetsLive.sort_by_saved_order(
      Settings.get([:ui, :widget_order, order_key(place)], %{}, opts),
      &WidgetsLive.order_key/1
    )
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Every widget a page can have, across its areas, for the viewer. See `offered/3`."
  def offered_on_page(place_module, context, opts \\ []) do
    place_module
    |> areas()
    |> Enum.flat_map(&offered({place_module, &1}, context, opts))
  end

  @doc "Widgets in the order a drop left them: `order` is the `Draggable` hook's `target_order`, matched by `key_fun`; unnamed ones go last."
  def sort_dropped(widgets, order, key_fun) do
    Enum.sort_by(widgets, fn widget ->
      Enum.find_index(order, &(&1 == key_fun.(widget))) || length(order)
    end)
  end

  @doc "Saves a place's order, hidden widgets included so they keep their place."
  def save_order(place, widgets, opts) do
    Bonfire.Common.Settings.LiveHandler.save_widget_order(
      order_key(place),
      Enum.map(widgets, &WidgetsLive.order_key/1),
      opts
    )
  end

  @doc "The key a place's saved order is under, eg. `:dashboard_main_widgets` for `{DashboardLive, :main}`."
  def order_key({place_module, key}) do
    name =
      place_module
      |> Module.split()
      |> List.last()
      |> String.replace_suffix("Live", "")
      |> Macro.underscore()

    :"#{name}_#{key}_widgets"
  end

  # the flavour's widgets for a place, as `{id, props}`
  defp default_entries({place_module, key}) do
    Config.get([place_module, :widgets], [])
    |> ed(key, [])
    |> List.wrap()
    |> Enum.map(fn
      {id, props} -> {Types.maybe_to_atom(id), List.wrap(props)}
      id -> {Types.maybe_to_atom(id), []}
    end)
  end

  defp fits?(widget, user, context) do
    (not widget.current_user_required or not is_nil(user)) and
      Bonfire.Common.Extend.module_enabled?(widget.module, if(user, do: context, else: []))
  end

  @doc "The areas of a page: the keys its flavour lists widgets under (`[:main]` when it lists none), eg. `[:main, :sidebar]`."
  def areas(place_module) do
    case Config.get([place_module, :widgets], []) do
      widgets when is_list(widgets) or is_map(widgets) ->
        case Enum.map(widgets, &elem(&1, 0)) do
          [] -> [:main]
          areas -> areas
        end

      _ ->
        [:main]
    end
  end

  # the one area of the page a widget sits in, or nil when none of them takes its width
  defp area_of(widget, place_module, areas, listed_in, opts) do
    case Enum.filter(areas, &allows?(widget.width, &1)) do
      [] ->
        nil

      [only] ->
        only

      allowed ->
        saved = Settings.get([place_module, :area, widget.id], nil, opts)

        Enum.find(allowed, &(to_string(&1) == to_string(saved))) ||
          Enum.find(allowed, &List.keymember?(listed_in[&1], widget.id, 0)) ||
          hd(allowed)
    end
  end

  defp allows?(:wide, area), do: not sidebar?(area)
  defp allows?(:narrow, area), do: sidebar?(area)
  defp allows?(_any, _area), do: true

  # where a widget that fits either goes when moved: a sidebar from the main area, and the main area from a sidebar
  defp other_area(area, areas), do: Enum.find(areas, &(sidebar?(&1) != sidebar?(area)))

  defp listed_props(listed_in, id),
    do:
      Enum.find_value(
        Map.values(listed_in),
        [],
        &(List.keyfind(&1, id, 0, {nil, nil}) |> elem(1))
      )

  defp sidebar?(key), do: String.contains?(to_string(key), "sidebar")

  # a widget can be on by default for a place and viewer beyond its flavour's list, with `included_by_default?(place, viewer)`
  defp included_by_default?(module, place, user) do
    Code.ensure_loaded?(module) and function_exported?(module, :included_by_default?, 2) and
      module.included_by_default?(place, user) == true
  end

  @doc "The widget `id` (an atom or string) as `Bonfire.UI.Common.WidgetsLive` renders it, for embedding on other sites: only one declared `embeddable` that guests can see, else nil."
  def embeddable(id) do
    id = to_string(id)

    case Enum.find(registry(), &(to_string(&1.id) == id)) do
      %{embeddable: true} = widget ->
        if fits?(widget, nil, []),
          do: %{
            id: widget.id,
            name: widget.name,
            module: widget.module,
            type: widget.type,
            order_id: widget[:order_id],
            data: List.wrap(widget.props)
          }

      _ ->
        nil
    end
  end

  @doc """
  The cache tag of a widget's embed, which is also the path its copies are saved under, one per query string.

      iex> Bonfire.UI.Common.Widgets.embed_tag(:instance_pinned)
      "embed/widget/instance_pinned"
  """
  def embed_tag(id), do: "embed/widget/#{id}"

  @doc "Purges every saved copy of a widget's embed: the ones on disk right away, and any proxy or CDN's in the background (see `Bonfire.Common.Cache.HTTPPurge`)."
  def bust_embed(id) do
    tags = [embed_tag(id)]
    Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator.bust_tags(tags)

    for adapter <- Bonfire.Common.Cache.HTTPPurge.adapters(),
        adapter != Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator do
      Task.start(fn -> adapter.bust_tags(tags) end)
    end

    :ok
  end

  @doc "Every widget, declared and custom, as `declared_widget/0` maps."
  def registry do
    declared() ++ custom()
  end

  @doc "The widgets extensions declare."
  def declared, do: Enum.reject(WidgetModule.widgets(), &is_nil/1)

  @doc "The custom widgets admins wrote, leaving out any without text. Instance settings are mirrored into config, so they're read from there."
  def custom do
    case Config.get([__MODULE__, :custom], nil) do
      stored when is_map(stored) or is_list(stored) ->
        Enum.flat_map(stored, fn {slug, widget} -> List.wrap(custom_widget(slug, widget)) end)

      _ ->
        []
    end
  end

  defp custom_widget(slug, stored) do
    case ed(stored, :text, nil) do
      text when is_binary(text) and text != "" ->
        title = ed(stored, :title, nil)
        id = :"custom_#{slug}"

        %{
          id: id,
          # saved orders key on this, as every custom widget is the same component
          order_id: id,
          name: if(is_binary(title) and title != "", do: title, else: l("Custom widget")),
          icon: nil,
          description: nil,
          width:
            case to_string(ed(stored, :width, nil)) do
              "wide" -> :wide
              "narrow" -> :narrow
              _ -> :any
            end,
          current_user_required: false,
          embeddable: true,
          props: [widget_title: title, text: text],
          module: Bonfire.UI.Common.WidgetTextLive,
          app: :bonfire_ui_common,
          type: Surface.Component
        }

      _ ->
        nil
    end
  end
end
