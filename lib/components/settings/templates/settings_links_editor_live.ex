defmodule Bonfire.UI.Common.SettingsLinksEditorLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop keys, :any, required: true
  prop scope, :any, default: :instance
  prop name, :string, default: nil
  prop description, :string, default: nil

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns[:links] do
      {:ok, socket}
    else
      links =
        if connected?(socket) do
          Bonfire.Common.Settings.get(assigns.keys, [], scope: assigns.scope)
          |> Bonfire.UI.Common.WidgetCommunityLinksLive.normalize_links(as: :map)
        else
          []
        end

      {:ok, assign(socket, links: links)}
    end
  end

  def handle_event("add_link", _, socket) do
    links = socket.assigns.links ++ [%{name: "", url: ""}]
    {:noreply, assign(socket, links: links)}
  end

  def handle_event("remove_link", %{"index" => index}, socket) do
    index = String.to_integer(index)
    links = List.delete_at(socket.assigns.links, index)
    {:noreply, assign(socket, links: links)}
  end

  def handle_event("save_links", params, socket) do
    links =
      params
      |> Map.get("links", %{})
      |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
      |> Enum.map(fn {_i, link} -> %{name: link["name"] || "", url: link["url"] || ""} end)
      |> Enum.reject(fn link -> link.name == "" and link.url == "" end)

    case Bonfire.Common.Settings.put(
           socket.assigns.keys,
           links,
           scope: socket.assigns.scope,
           socket: socket
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(links: links)
         |> assign_flash(:info, l("Links saved"))}

      {:error, _reason} ->
        {:noreply, assign_flash(socket, :error, l("Could not save links"))}
    end
  end
end
