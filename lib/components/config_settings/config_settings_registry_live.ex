defmodule Bonfire.UI.Common.ConfigSettingsRegistryLive do
  @moduledoc """
  LiveView for displaying registered configuration and settings keys.
  """
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.Common.ConfigSettingsRegistry

  prop scope, :any, default: nil

  @impl true
  def update(assigns, %{assigns: %{registry: _}} = socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(assigns, socket) do
    registry = ConfigSettingsRegistry.format_registry()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       page_title: "Configuration & Settings Registry",
       registry: registry,
       current_tab: :settings,
       search_term: "",
       filtered_config: registry.config,
       filtered_settings: registry.settings
     )}
  end

  @impl true
  def handle_event("tab_change", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, current_tab: String.to_atom(tab))}
  end

  @impl true
  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    registry = socket.assigns.registry

    # Filter config items
    filtered_config = filter_items(registry.config, term)

    # Filter settings items
    filtered_settings = filter_items(registry.settings, term)

    {:noreply,
     assign(socket,
       search_term: term,
       filtered_config: filtered_config,
       filtered_settings: filtered_settings
     )}
  end

  defp filter_items(items, "") do
    items
  end

  defp filter_items(items, term) do
    Enum.filter(items, fn item ->
      keys_str = ConfigSettingsListLive.format_key_for_display(item.keys)
      default_str = ConfigSettingsListLive.format_value(item.default)

      # Check if the term appears in the keys or default value
      keys_match = String.contains?(String.downcase(keys_str), String.downcase(term))
      default_match = String.contains?(String.downcase(default_str), String.downcase(term))

      # # Check if the term appears in any of the locations (module, file, or location-specific default)
      # locations_match = Enum.any?(item.locations, fn loc ->
      #   module_str = to_string(loc.module)
      #   file_str = to_string(loc.file)
      #   loc_default_str = to_string(loc.default)

      #   String.contains?(String.downcase(module_str), String.downcase(term)) ||
      #   String.contains?(String.downcase(file_str), String.downcase(term)) ||
      #   String.contains?(String.downcase(loc_default_str), String.downcase(term))
      # end)

      # || locations_match
      keys_match || default_match
    end)
  end
end
