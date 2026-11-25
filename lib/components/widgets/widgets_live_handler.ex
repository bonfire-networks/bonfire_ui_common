defmodule Bonfire.UI.Common.Widgets.LiveHandler do
  @moduledoc """
  Edit mode's events: a signed-in person changes a page's widgets on the page itself, for themselves only.

  The page is `socket.view`, never read from params. Saves use the settings page's keys (see `Bonfire.UI.Common.PlaceWidgetsSettingsLive`).
  """
  use Bonfire.UI.Common.Web, :live_handler

  alias Bonfire.Common.Settings
  alias Bonfire.UI.Common.Widgets

  def handle_event("remove", %{"id" => id}, socket) do
    page = socket.view
    user = current_user(socket)

    with %{} = widget <- find(page, user, id),
         {:ok, settings} <- Settings.put([page, :include, widget.id], false, current_user: user) do
      {:noreply, refresh(socket, settings, %{id: widget.id, name: widget.name})}
    else
      other -> failed(socket, other, l("Could not remove the widget. Please try again."))
    end
  end

  # its order was kept, so it goes back where it was
  def handle_event("undo", %{"id" => id}, socket) do
    page = socket.view
    user = current_user(socket)

    with %{} = widget <- find(page, user, id),
         {:ok, settings} <- Settings.put([page, :include, widget.id], true, current_user: user) do
      {:noreply, refresh(socket, settings, nil)}
    else
      other -> failed(socket, other, l("Could not put the widget back. Please try again."))
    end
  end

  def handle_event("add", %{"id" => id, "area" => area}, socket) do
    page = socket.view
    user = current_user(socket)

    with area when not is_nil(area) <- area_named(page, area),
         %{} = widget <- find(page, user, id),
         true <- widget.area == area or widget.move_to == area,
         {:ok, settings} <- maybe_move(page, widget, area, user),
         user = updated_user(settings, user),
         {:ok, settings} <- Settings.put([page, :include, widget.id], true, current_user: user),
         user = updated_user(settings, user),
         others = Enum.reject(Widgets.offered({page, area}, user), &(&1.id == widget.id)),
         {:ok, settings} <-
           Widgets.save_order({page, area}, others ++ [widget], current_user: user) do
      Bonfire.UI.Common.OpenModalLive.close()
      {:noreply, refresh(socket, settings, removed_unless(socket, widget.id))}
    else
      {:error, _} = error ->
        failed(socket, error, l("Could not add the widget. Please try again."))

      # gone or no longer fitting since the sheet was rendered
      _ ->
        Bonfire.UI.Common.OpenModalLive.close()

        {:noreply,
         socket
         |> assign_flash(:error, l("This widget can't be added there any more."))
         |> assign(Widgets.place_assigns(page, user, socket.assigns[:widgets_removed]))}
    end
  end

  # a drop from the `Draggable` hook, within or across areas; one the widget's width doesn't allow is refused
  def handle_event(
        "reorder",
        %{"parent_item" => from_list, "source_item" => item, "target_order" => order} = params,
        socket
      ) do
    page = socket.view
    user = current_user(socket)
    from = area_of_list(page, from_list)
    to = area_of_list(page, params["target_parent"] || from_list)

    with true <- not is_nil(from) and not is_nil(to),
         %{} = widget <-
           Enum.find(Widgets.offered({page, from}, user), &(order_key(&1) == item)),
         true <- from == to or widget.move_to == to,
         {:ok, settings} <- maybe_move(page, widget, to, user),
         user = updated_user(settings, user),
         dropped = Widgets.sort_dropped(Widgets.offered({page, to}, user), order, &order_key/1),
         {:ok, settings} <- Widgets.save_order({page, to}, dropped, current_user: user) do
      {:noreply, refresh(socket, settings)}
    else
      {:error, _} = error ->
        failed(socket, error, l("Could not move the widget. Please try again."))

      # the hook puts the item back on `refused`: an unchanged render sends no patch
      _ ->
        {:reply, %{refused: true}, socket}
    end
  end

  defp find(page, user, id),
    do: Enum.find(Widgets.offered_on_page(page, user), &(to_string(&1.id) == id))

  # matched against the page's own areas, never turned into an atom
  defp area_named(page, name), do: Enum.find(Widgets.areas(page), &(to_string(&1) == name))

  # the hook names a list by its `data-parent`, the area's order key
  defp area_of_list(page, list),
    do: Enum.find(Widgets.areas(page), &(to_string(Widgets.order_key({page, &1})) == list))

  defp maybe_move(_page, %{area: area}, area, _user), do: {:ok, nil}

  defp maybe_move(page, widget, area, user),
    do: Settings.put([page, :area, widget.id], area, current_user: user)

  defp order_key(widget), do: to_string(Bonfire.UI.Common.WidgetsLive.order_key(widget))

  # each put returns the person with their settings preloaded
  defp updated_user(settings, user), do: e(settings, :__context__, :current_user, nil) || user

  # keeps a pending Undo unless told otherwise
  defp refresh(socket, settings, removed \\ :keep) do
    removed = if removed == :keep, do: socket.assigns[:widgets_removed], else: removed
    socket = maybe_assign_context(socket, settings)

    assign(
      socket,
      Widgets.place_assigns(socket.view, updated_user(settings, current_user(socket)), removed)
    )
  end

  defp removed_unless(socket, id) do
    case socket.assigns[:widgets_removed] do
      %{id: ^id} -> nil
      removed -> removed
    end
  end

  defp failed(socket, {:error, _} = error, message) do
    error(error, "Could not save a widget change")
    {:noreply, assign_flash(socket, :error, message)}
  end

  defp failed(socket, _not_found, _message), do: {:noreply, socket}
end
