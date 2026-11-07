defmodule Bonfire.UI.Common.SettingsListsLive do
  @moduledoc """
  Edits several settings that are each a list of strings, side by side, and moves an item from one to another (eg. filter keywords that hide a post completely, and those that only close it behind a warning). An item is in one list at most: adding it to a list, or moving it there, takes it out of the others.

  One component owns all the lists, so a move saves both of them; two `Bonfire.UI.Common.SettingsListLive` would each keep their own copy, and a move in one would leave the other stale. Reads, saves and the add field's parsing are `Bonfire.UI.Common.SettingsListLive`'s.

  Props:
    * `lists` — one map per list: `keys` (the setting), `name` (also the add field's label) and `description`.
    * `scope` — the scope of every list.
    * `name`/`description` — about all the lists.
    * `placeholder`, `normalize`, `allow_bulk_paste` — as `Bonfire.UI.Common.SettingsListLive`.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Common.SettingsListLive

  prop lists, :list, required: true
  prop scope, :any, default: :instance
  prop name, :string, default: nil
  prop description, :string, default: nil
  prop placeholder, :string, default: nil
  prop normalize, :any, default: nil
  prop allow_bulk_paste, :boolean, default: false

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns[:items] do
      {:ok, socket}
    else
      items =
        Enum.map(assigns.lists, fn list ->
          if connected?(socket),
            do: SettingsListLive.read_items(list[:keys], assigns.scope, socket),
            else: []
        end)

      {:ok, assign(socket, items: items)}
    end
  end

  def handle_event("add_item", %{"item" => raw, "list" => to}, socket) do
    case SettingsListLive.new_items(raw, socket.assigns) do
      [] ->
        {:noreply, socket}

      new_items ->
        save(socket, put_in_list(socket.assigns.items, String.to_integer(to), new_items))
    end
  end

  def handle_event("remove_item", %{"list" => list, "index" => index}, socket) do
    socket.assigns.items
    |> List.update_at(String.to_integer(list), &List.delete_at(&1, String.to_integer(index)))
    |> then(&save(socket, &1))
  end

  def handle_event("move_item", %{"from" => from, "index" => index, "to" => to}, socket) do
    case socket.assigns.items
         |> Enum.at(String.to_integer(from), [])
         |> Enum.at(String.to_integer(index)) do
      nil -> {:noreply, socket}
      item -> save(socket, put_in_list(socket.assigns.items, String.to_integer(to), [item]))
    end
  end

  @doc "The id of one list's section, eg. `filter_keywords_warn` for a list whose keys end in `:warn`"
  def list_id(id, list), do: "#{id}_#{List.last(List.wrap(list[:keys]))}"

  # adds `new_items` to list `to` and takes them out of every other list
  defp put_in_list(items, to, new_items) do
    items
    |> Enum.with_index()
    |> Enum.map(fn
      {list_items, ^to} -> Enum.uniq(list_items ++ new_items)
      {list_items, _} -> list_items -- new_items
    end)
  end

  # saves the lists that changed, in one write: a second write would start from the settings loaded before the first, and put back what the first removed. At the keys they share (eg. `[:activity_pub, :mrf_keyword]`), whose other keys the merge keeps
  defp save(socket, items) do
    changed =
      Enum.zip([socket.assigns.lists, socket.assigns.items, items])
      |> Enum.reject(fn {_list, old, new} -> old == new end)
      |> Enum.map(fn {list, _old, new} -> {List.wrap(list[:keys]), new} end)

    case changed do
      [] ->
        nil

      [{keys, list_items}] ->
        SettingsListLive.save_items(keys, list_items, socket.assigns.scope, socket)

      changed ->
        prefix = common_prefix(Enum.map(changed, &elem(&1, 0)))

        changed
        |> Enum.reduce(%{}, fn {keys, list_items}, acc ->
          Bonfire.Common.Enums.deep_merge(
            acc,
            Bonfire.Common.Enums.map_put_in(Enum.drop(keys, length(prefix)), list_items)
          )
        end)
        |> then(&SettingsListLive.save_items(prefix, &1, socket.assigns.scope, socket))
    end

    {:noreply, assign(socket, items: items)}
  end

  defp common_prefix([first | rest]) do
    Enum.reduce(rest, first, fn keys, prefix ->
      prefix
      |> Enum.zip(keys)
      |> Enum.take_while(fn {a, b} -> a == b end)
      |> Enum.map(&elem(&1, 0))
    end)
  end
end
