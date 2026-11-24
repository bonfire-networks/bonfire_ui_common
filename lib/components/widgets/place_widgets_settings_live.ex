defmodule Bonfire.UI.Common.PlaceWidgetsSettingsLive do
  @moduledoc """
  Settings for one place's widgets (eg. the dashboard's main area, or the guest home): every widget it can have, each with a toggle to show it, buttons to move it, and for one that fits more than one area of the page, a button to move it to the other area. See `Bonfire.UI.Common.Widgets.offered/3`.

  A person's own choices, or with `scope: :instance` the instance's defaults. With `for_guests`, it lists what guests can see.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Common.Widgets
  alias Bonfire.UI.Common.WidgetsLive

  # `{PlaceModule, key}`, eg. `{Bonfire.Web.Views.DashboardLive, :main}`
  prop place, :any, required: true
  prop scope, :any, default: nil
  # list what guests can see, rather than what the viewer can
  prop for_guests, :boolean, default: false

  # the ids of the lists for the page's other areas, which show a widget that moves out of this one
  prop siblings, :list, default: []

  data widgets, :list, default: []

  def update(assigns, socket) do
    {viewer, assigns} = Map.pop(assigns, :refreshed_viewer)
    socket = assign(socket, assigns)
    {:ok, assign(socket, widgets: offered(socket, viewer))}
  end

  # `viewer` is the person with their just-saved settings, as the socket's own copy is only updated once the page has handled the change
  defp offered(socket, viewer) do
    viewer = if socket.assigns.for_guests, do: nil, else: viewer || current_user(socket)
    Widgets.offered(socket.assigns.place, viewer, scope: socket.assigns.scope)
  end

  defp sidebar?(area), do: String.contains?(to_string(area), "sidebar")

  def handle_event("move", %{"key" => key, "direction" => direction}, socket) do
    widgets = socket.assigns.widgets

    with index when is_integer(index) <- Enum.find_index(widgets, &(to_string(&1.id) == key)),
         to = if(direction == "up", do: index - 1, else: index + 1),
         true <- to in 0..(length(widgets) - 1)//1,
         widgets = Enum.slide(widgets, index, to),
         {:ok, settings} <- save_order(widgets, socket) do
      {:noreply, socket |> assign(:widgets, widgets) |> maybe_assign_context(settings)}
    else
      {:error, _} = failed ->
        error(failed, "Could not save the widget order")

        {:noreply,
         assign_flash(socket, :error, l("Could not save the new order. Please try again."))}

      _ ->
        {:noreply, socket}
    end
  end

  # a widget that fits more than one area of the page moves to the other one, which saves its area (`[PlaceModule, :area, id]`) at the list's scope
  def handle_event("move_area", %{"key" => key}, socket) do
    {place_module, _key} = socket.assigns.place

    with %{id: id, move_to: to} when not is_nil(to) <-
           Enum.find(socket.assigns.widgets, &(to_string(&1.id) == key)),
         {:ok, settings} <-
           Bonfire.Common.Settings.put([place_module, :area, id], to, save_opts(socket)) do
      socket = maybe_assign_context(socket, settings)
      viewer = e(settings, :__context__, :current_user, nil)

      for sibling <- socket.assigns.siblings,
          do: Phoenix.LiveView.send_update(__MODULE__, id: sibling, refreshed_viewer: viewer)

      {:noreply, assign(socket, :widgets, offered(socket, viewer))}
    else
      {:error, _} = failed ->
        error(failed, "Could not save the widget's area")

        {:noreply,
         assign_flash(socket, :error, l("Could not move the widget. Please try again."))}

      _ ->
        {:noreply, socket}
    end
  end

  # a widget dropped by the `Draggable` hook, in this list or in the list of another area of the page
  def handle_event(
        "reorder_widgets",
        %{"source_item" => key, "target_order" => order} = params,
        socket
      ) do
    target = params["target_parent"] || to_string(socket.assigns.id)

    cond do
      target == to_string(socket.assigns.id) ->
        reorder_here(key, order, socket)

      target in Enum.map(socket.assigns.siblings, &to_string/1) ->
        drop_in_sibling(key, target, order, socket)

      true ->
        {:noreply, socket}
    end
  end

  defp reorder_here(_key, order, socket) do
    widgets = socket.assigns.widgets
    sorted = sort_dropped(widgets, order)

    with true <- sorted != widgets,
         {:ok, settings} <- save_order(sorted, socket) do
      {:noreply, socket |> assign(:widgets, sorted) |> maybe_assign_context(settings)}
    else
      {:error, _} = failed ->
        error(failed, "Could not save the widget order")

        {:noreply,
         assign_flash(socket, :error, l("Could not save the new order. Please try again."))}

      _ ->
        {:noreply, socket}
    end
  end

  # the widget's width decides whether the other area takes it (`move_to`), as for the move button; the target list's order is then saved with the widget in its dropped position
  defp drop_in_sibling(key, target, order, socket) do
    {place_module, _key} = socket.assigns.place

    with %{id: id, move_to: to} when not is_nil(to) <-
           Enum.find(socket.assigns.widgets, &(to_string(&1.id) == key)),
         {:ok, settings} <-
           Bonfire.Common.Settings.put([place_module, :area, id], to, save_opts(socket)),
         viewer = e(settings, :__context__, :current_user, nil),
         moved_to =
           Widgets.offered(
             {place_module, to},
             if(socket.assigns.for_guests, do: nil, else: viewer),
             scope: socket.assigns.scope
           ),
         {:ok, settings} <-
           Bonfire.Common.Settings.LiveHandler.save_widget_order(
             Widgets.order_key({place_module, to}),
             order_keys(moved_to, order),
             save_opts(socket, viewer)
           ) do
      socket = maybe_assign_context(socket, settings)
      viewer = e(settings, :__context__, :current_user, nil) || viewer

      Phoenix.LiveView.send_update(__MODULE__, id: target, refreshed_viewer: viewer)

      {:noreply, assign(socket, :widgets, offered(socket, viewer))}
    else
      {:error, _} = failed ->
        error(failed, "Could not save the widget's area")

        {:noreply,
         assign_flash(socket, :error, l("Could not move the widget. Please try again."))}

      _ ->
        {:noreply, socket}
    end
  end

  # the order keys of a list's widgets as dropped, those the drop doesn't name after
  defp order_keys(widgets, order),
    do: widgets |> sort_dropped(order) |> Enum.map(&WidgetsLive.order_key/1)

  defp sort_dropped(widgets, order) do
    Enum.sort_by(widgets, fn widget ->
      Enum.find_index(order, &(&1 == to_string(widget.id))) || length(order)
    end)
  end

  # the order of every offered widget, hidden ones included so they keep their place
  defp save_order(widgets, socket) do
    Bonfire.Common.Settings.LiveHandler.save_widget_order(
      Widgets.order_key(socket.assigns.place),
      Enum.map(widgets, &WidgetsLive.order_key/1),
      save_opts(socket)
    )
  end

  # `user` is the person with their just-saved settings, when a save follows another
  defp save_opts(socket, user \\ nil) do
    user = user || current_user(socket)

    if socket.assigns.scope == :instance,
      do: [current_user: user, scope: :instance],
      else: [current_user: user]
  end
end
