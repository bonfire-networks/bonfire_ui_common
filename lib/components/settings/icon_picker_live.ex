defmodule Bonfire.UI.Common.IconPickerLive do
  @moduledoc """
  A grid of icons to choose one from, with a Reset to none. It only shows and sends: each icon sends `event` with its name as `icon` (and `object_id` as `id`), Reset sends `reset_event`, both to `target`. What they do is the caller's, eg. `Bonfire.Classify.Web.AppearanceLive`.

  Offers the `icons` it is given (a list of names, eg. `curated_icons/0`), or with none, every icon of the compiled set, as `/settings/instance/icons` lists them, found with a search (a few at a time, as there are hundreds).

  Icons are drawn from the compiled CSS by name, and iconify_ex builds a rule for a name only when it finds it written out. So the module builds the rule of each of `curated_icons/0` as it compiles, as a literal `<#Icon>` would, whatever uses the list (this module, or an icon name in a config).
  """
  use Bonfire.UI.Common.Web, :stateful_component

  # the three lists are in config/bonfire_ui_common.exs, read when this compiles: changing them needs a recompile of bonfire_ui_common, which also builds their CSS (below)
  @category_icons Application.compile_env!(:bonfire_ui_common, [__MODULE__, :category_icons])
  @more_icons Application.compile_env!(:bonfire_ui_common, [__MODULE__, :more_icons])
  @themed_icons Application.compile_env!(:bonfire_ui_common, [__MODULE__, :themed_icons])

  @curated @category_icons ++ @more_icons ++ @themed_icons

  # builds each icon's CSS rule while this compiles (it is only added to the stylesheet, so a rule already there stays)
  for icon <- @curated, do: Iconify.prepare(icon, :css)

  @doc "The icons offered for a topic, group or label: the 35 the event categories start with, then 42 more, then 35 by theme (all in the compiled set)."
  def curated_icons, do: @curated

  @doc "Whether an icon may be picked: one of `curated_icons/0`, or one of the compiled set."
  def offered?(icon) when is_binary(icon), do: icon in @curated or icon in compiled_icons()
  def offered?(_), do: false

  @doc "Every icon of the compiled set, by name."
  def compiled_icons do
    for {_family, icons} <- Iconify.list_all_existing(),
        icon <- icons,
        is_binary(icon),
        String.contains?(icon, ":"),
        uniq: true,
        do: icon
  rescue
    # the stylesheet is not where this runs (eg. a release without the assets)
    _ -> []
  end

  # the most a search shows
  @max_found 60

  @doc "The icon's name to read, eg. `ph:music-notes-fill` is \"music notes\"."
  def readable(icon) do
    icon
    |> String.replace(~r/^[^:]*:/, "")
    |> String.replace_suffix("-fill", "")
    |> String.replace("-", " ")
  end

  @doc "Every icon is the caller's list, or the compiled ones that a search finds."
  def shown(nil, search) do
    case search |> to_string() |> String.trim() |> String.downcase() do
      term when byte_size(term) >= 2 ->
        compiled_icons()
        |> Enum.filter(&String.contains?(&1, term))
        |> Enum.take(@max_found)

      _ ->
        []
    end
  end

  def shown(icons, _search), do: icons

  @doc "The icons offered, given or all of the compiled set."
  prop icons, :list, default: nil
  @doc "The icon the thing has of its own, if any"
  prop selected, :string, default: nil
  prop object_id, :any, default: nil
  prop event, :string, required: true
  prop reset_event, :string, required: true
  @doc "Where the events go, eg. the caller's `@myself`"
  prop target, :any, default: nil

  data search, :string, default: ""

  def handle_event("search", %{"search" => search}, socket),
    do: {:noreply, assign(socket, search: search)}
end
