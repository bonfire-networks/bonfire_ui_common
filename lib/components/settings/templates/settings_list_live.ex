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
          do:
            Settings.get(assigns.keys, [],
              scope: assigns.scope,
              current_user: current_user(socket)
            )
            |> List.wrap(),
          else: []

      {:ok, assign(socket, items: items)}
    end
  end

  def handle_event("add_item", %{"item" => raw}, socket) do
    new_items =
      raw
      |> split(socket.assigns.allow_bulk_paste)
      |> Enum.map(&normalize(&1, socket.assigns.normalize))
      |> Enum.reject(&(&1 == ""))

    if new_items == [] do
      {:noreply, socket}
    else
      save(socket, Enum.uniq(socket.assigns.items ++ new_items))
    end
  end

  def handle_event("remove_item", %{"index" => idx}, socket) do
    save(socket, List.delete_at(socket.assigns.items, String.to_integer(idx)))
  end

  defp split(raw, true), do: String.split(raw, ~r/[,\n]+/)
  defp split(raw, _), do: [raw]

  defp normalize(item, fun) when is_function(fun, 1), do: fun.(item)
  defp normalize(item, _), do: String.trim(item)

  defp save(socket, items) do
    Settings.put(socket.assigns.keys, items,
      scope: socket.assigns.scope,
      current_user: current_user(socket)
    )

    {:noreply, assign(socket, items: items)}
  end
end
