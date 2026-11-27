defmodule Bonfire.UI.Common.Widgets.LiveHandler do
  @moduledoc """
  Edit mode's events: a signed-in person changes a page's widgets on the page itself, for themselves only, or on a settings page (`assign_settings_page/4`), where an admin can set the instance's defaults.

  The page is `socket.view`, or the settings page's `widgets_place`, never read from params. Saves use the same keys as `Bonfire.UI.Common.Widgets`.
  """
  use Bonfire.UI.Common.Web, :live_handler

  alias Bonfire.Common.Settings
  alias Bonfire.UI.Common.Widgets

  @doc """
  Sets up a settings page that edits another page's widgets, eg. the dashboard's from `/settings/user/dashboard`: assigns `widgets_place`, `widgets_scope` (`:instance` for the instance's defaults, else the viewer's own), `widgets_for_guests` and `widgets_editing`, the `Widgets.place_assigns/4` of that page as a map.

  With `for_guests: true` it offers the widgets guests can see, for a guest page (eg. the homepage).

  They live under their own keys so the settings page's layout keeps its own `sidebar_widgets`.
  """
  def assign_settings_page(socket, place_module, scope, opts \\ []) do
    scope = if scope == :instance, do: :instance

    socket
    |> assign(
      widgets_place: place_module,
      widgets_scope: scope,
      widgets_for_guests: opts[:for_guests] == true
    )
    |> assign_widgets(current_user(socket), nil)
  end

  # the custom widget form (`Bonfire.UI.Common.CustomWidgetFormLive`, only rendered on a settings page), saved as any settings form. The sheet closes and the page's widgets are recomputed, so reopening it shows the new widget's card (the open sheet keeps what it opened with)
  def handle_event("save_custom", attrs, socket) do
    case Bonfire.Common.Settings.LiveHandler.handle_event("save", attrs, socket) do
      {:noreply, socket} ->
        Bonfire.UI.Common.OpenModalLive.close()
        {:noreply, assign_widgets(socket, current_user(socket), removed(socket))}

      other ->
        other
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    {page, scope} = page_and_scope(socket)
    user = current_user(socket)

    with %{} = widget <- find(page, viewer(socket, user), scope, id),
         {:ok, settings} <-
           Settings.put([page, :include, widget.id], false, put_opts(user, scope)) do
      {:noreply, refresh(socket, settings, %{id: widget.id, name: widget.name})}
    else
      other -> failed(socket, other, l("Could not remove the widget. Please try again."))
    end
  end

  # its order was kept, so it goes back where it was
  def handle_event("undo", %{"id" => id}, socket) do
    {page, scope} = page_and_scope(socket)
    user = current_user(socket)

    with %{} = widget <- find(page, viewer(socket, user), scope, id),
         {:ok, settings} <- Settings.put([page, :include, widget.id], true, put_opts(user, scope)) do
      {:noreply, refresh(socket, settings, nil)}
    else
      other -> failed(socket, other, l("Could not put the widget back. Please try again."))
    end
  end

  def handle_event("add", %{"id" => id, "area" => area}, socket) do
    {page, scope} = page_and_scope(socket)
    user = current_user(socket)

    with area when not is_nil(area) <- area_named(page, area),
         %{} = widget <- find(page, viewer(socket, user), scope, id),
         true <- widget.area == area or widget.move_to == area,
         {:ok, settings} <- maybe_move(page, widget, area, user, scope),
         user = updated_user(settings, user),
         {:ok, settings} <- Settings.put([page, :include, widget.id], true, put_opts(user, scope)),
         user = updated_user(settings, user),
         others =
           Enum.reject(
             Widgets.offered({page, area}, viewer(socket, user), scope: scope),
             &(&1.id == widget.id)
           ),
         {:ok, settings} <-
           Widgets.save_order({page, area}, others ++ [widget], put_opts(user, scope)) do
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
         |> assign_widgets(user, removed(socket))}
    end
  end

  # a drop from the `Draggable` hook, within or across areas; one the widget's width doesn't allow is refused
  def handle_event(
        "reorder",
        %{"parent_item" => from_list, "source_item" => item, "target_order" => order} = params,
        socket
      ) do
    {page, scope} = page_and_scope(socket)
    user = current_user(socket)
    from = area_of_list(page, from_list)
    to = area_of_list(page, params["target_parent"] || from_list)

    with true <- not is_nil(from) and not is_nil(to),
         %{} = widget <-
           Enum.find(
             Widgets.offered({page, from}, viewer(socket, user), scope: scope),
             &(order_key(&1) == item)
           ),
         true <- from == to or widget.move_to == to,
         {:ok, settings} <- maybe_move(page, widget, to, user, scope),
         user = updated_user(settings, user),
         dropped =
           Widgets.sort_dropped(
             Widgets.offered({page, to}, viewer(socket, user), scope: scope),
             order,
             &order_key/1
           ),
         {:ok, settings} <- Widgets.save_order({page, to}, dropped, put_opts(user, scope)) do
      {:noreply, refresh(socket, settings)}
    else
      {:error, _} = error ->
        failed(socket, error, l("Could not move the widget. Please try again."))

      # the hook puts the item back on `refused`: an unchanged render sends no patch
      _ ->
        {:reply, %{refused: true}, socket}
    end
  end

  # a settings page names the page it edits (`assign_settings_page/4`); any other page edits itself
  defp page_and_scope(socket) do
    case socket.assigns[:widgets_place] do
      nil -> {socket.view, nil}
      place -> {place, socket.assigns[:widgets_scope]}
    end
  end

  # whom the widgets are offered to: nobody on a guest page's settings, else the person editing
  defp viewer(socket, user), do: if(socket.assigns[:widgets_for_guests], do: nil, else: user)

  # `Settings.put/3` refuses instance scope to anyone but an admin
  defp put_opts(user, :instance), do: [current_user: user, scope: :instance]
  defp put_opts(user, _), do: [current_user: user]

  defp find(page, user, scope, id),
    do:
      Enum.find(
        Widgets.offered_on_page(page, user, scope: scope),
        &(to_string(&1.id) == id)
      )

  # matched against the page's own areas, never turned into an atom
  defp area_named(page, name), do: Enum.find(Widgets.areas(page), &(to_string(&1) == name))

  # the hook names a list by its `data-parent`, the area's order key
  defp area_of_list(page, list),
    do: Enum.find(Widgets.areas(page), &(to_string(Widgets.order_key({page, &1})) == list))

  defp maybe_move(_page, %{area: area}, area, _user, _scope), do: {:ok, nil}

  defp maybe_move(page, widget, area, user, scope),
    do: Settings.put([page, :area, widget.id], area, put_opts(user, scope))

  defp order_key(widget), do: to_string(Bonfire.UI.Common.WidgetsLive.order_key(widget))

  # each put returns the person with their settings preloaded
  defp updated_user(settings, user), do: e(settings, :__context__, :current_user, nil) || user

  # keeps a pending Undo unless told otherwise
  defp refresh(socket, settings, removed \\ :keep) do
    removed = if removed == :keep, do: removed(socket), else: removed

    socket
    |> maybe_assign_context(settings)
    |> assign_widgets(updated_user(settings, current_user(socket)), removed)
  end

  defp assign_widgets(socket, user, removed) do
    case page_and_scope(socket) do
      {page, nil} when page == socket.view ->
        assign(socket, Widgets.place_assigns(page, user, removed))

      {page, scope} ->
        assign(socket,
          widgets_editing:
            Map.new(
              Widgets.place_assigns(page, user, removed,
                scope: scope,
                for_guests: socket.assigns[:widgets_for_guests]
              )
            )
        )
    end
  end

  defp removed(socket),
    do:
      e(socket.assigns, :widgets_editing, :widgets_removed, nil) ||
        socket.assigns[:widgets_removed]

  defp removed_unless(socket, id) do
    case removed(socket) do
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
