defmodule Bonfire.UI.Common.SettingsListLive do
  @moduledoc """
  Generic list editor for a setting whose value is a list of strings (e.g. allowed email domains, filter keywords). Reads and writes the setting at `keys`/`scope` via `Bonfire.Common.Settings`.

  TODO: this handles the unordered (chips) case; `Bonfire.UI.Common.ExtraLocalesLive` is its ordered cousin (add/remove plus reorder, where position matters). Consider merging them or creating another for ordered lists, based on that one.

  Props:
    * `keys`/`scope` — the setting to edit.
    * `name`/`description`/`placeholder` — labels.
    * `normalize` — optional `(String.t -> String.t)` applied to each added item (default trims).
    * `allow_bulk_paste` — when true, an added value is split on commas/newlines into several items.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Common.Settings

  prop keys, :any, required: true
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
        if connected?(socket),
          do: read_items(assigns.keys, assigns.scope, socket),
          else: []

      {:ok, assign(socket, items: items)}
    end
  end

  def handle_event("add_item", %{"item" => raw}, socket) do
    case new_items(raw, socket.assigns) do
      [] -> {:noreply, socket}
      new_items -> save(socket, Enum.uniq(socket.assigns.items ++ new_items))
    end
  end

  def handle_event("remove_item", %{"index" => idx}, socket) do
    save(socket, List.delete_at(socket.assigns.items, String.to_integer(idx)))
  end

  @doc "The items typed in an add field: split on commas and newlines when `allow_bulk_paste`, each normalised (`normalize`, else trimmed), empty ones dropped. Shared with `Bonfire.UI.Common.SettingsListsLive`"
  def new_items(raw, assigns) do
    raw
    |> split(assigns[:allow_bulk_paste])
    |> Enum.map(&normalize(&1, assigns[:normalize]))
    |> Enum.reject(&(&1 == ""))
  end

  defp split(raw, true), do: String.split(raw, ~r/[,\n]+/)
  defp split(raw, _), do: [raw]

  defp normalize(item, fun) when is_function(fun, 1), do: fun.(item)
  defp normalize(item, _), do: String.trim(item)

  @doc "Reads the list at `keys` for `scope`. Only the list of the scope being edited: a merged read would show (and on the next save, copy into the user's own settings) the instance's list too, or an admin's own list in the instance's"
  def read_items(keys, scope, socket),
    do: keys |> Settings.get([], read_opts(scope, socket)) |> List.wrap()

  defp read_opts(:user, socket), do: [current_user: current_user(socket), one_scope_only: true]
  defp read_opts(scope, _socket), do: [scope: scope]

  @doc "Saves the list at `keys` for `scope` with `put_raw`, not `put`: the items are strings and stay strings (`put` would turn \"2026\" into a number and \"Enum\" into a module)"
  def save_items(keys, items, scope, socket) do
    Settings.put_raw(keys, items, scope: scope, current_user: current_user(socket))
  end

  defp save(socket, items) do
    save_items(socket.assigns.keys, items, socket.assigns.scope, socket)
    {:noreply, assign(socket, items: items)}
  end
end
