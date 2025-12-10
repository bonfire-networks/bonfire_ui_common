defmodule Bonfire.UI.Common.ExtraLocalesLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Common.Settings
  alias Bonfire.Common.Localise

  @doc """
  Component for managing extra locales (languages user understands).
  """
  prop label, :string, default: nil
  prop description, :string, default: nil

  prop extra_locales, :list, required: true
  prop primary_locale, :string, required: true
  prop scope, :any, required: true

  def handle_event("move_extra_locale_up", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    extra_locales = socket.assigns.extra_locales
    new_locales = move_item(extra_locales, idx, idx - 1)
    save_and_update(socket, new_locales)
  end

  def handle_event("move_extra_locale_down", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    extra_locales = socket.assigns.extra_locales
    new_locales = move_item(extra_locales, idx, idx + 1)
    save_and_update(socket, new_locales)
  end

  def handle_event("remove_extra_locale", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    extra_locales = List.delete_at(socket.assigns.extra_locales, idx)
    save_and_update(socket, extra_locales)
  end

  def handle_event("add_extra_locale", %{"new_locale" => locale}, socket) do
    if locale == "" do
      {:noreply, socket}
    else
      extra_locales =
        socket.assigns.extra_locales
        |> Enum.concat([locale])
        |> Enum.uniq()
        |> Enum.reject(&(&1 == socket.assigns.primary_locale))

      save_and_update(socket, extra_locales)
    end
  end

  defp save_and_update(socket, new_locales) do
    Settings.put([Bonfire.Common.Localise, :extra_locales], new_locales, context: assigns(socket))
    {:noreply, assign(socket, extra_locales: new_locales)}
  end

  @doc """
  Moves an item in a list from one index to another.
  ## Examples
      iex> move_item(["a", "b", "c"], 2, 0)
      ["c", "a", "b"]
  """
  def move_item(list, from, to)
      when from != to and from in 0..(length(list) - 1) and to in 0..(length(list) - 1) do
    item = Enum.at(list, from)

    list
    |> List.delete_at(from)
    |> List.insert_at(to, item)
  end

  def move_item(list, _, _), do: list
end
