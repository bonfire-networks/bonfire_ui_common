defmodule Bonfire.UI.Common.ExtensionsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  # import Bonfire.Common.Extensions

  prop scope, :any, default: nil
  prop extensions_config, :boolean, default: false
  prop feature_extensions, :list, default: []
  prop ui, :list, default: []
  # prop schemas, :list, default: []
  # prop ecosystem_libs, :list, default: []
  # prop other_deps, :list, default: []

  prop settings_section_title, :string, default: "Bonfire extensions"

  def update(assigns, socket) do
    if socket_connected?(assigns) do
      {:ok,
       socket
       |> assign(assigns)
       |> assign_new(:data, fn -> cached_data() end)
       |> assign_new(:can_instance_wide, fn ->
         Bonfire.Boundaries.can?(assigns[:__context__], :toggle, :instance)
       end)}
    else
      {:ok,
       socket
       |> assign(assigns)
       |> assign_new(:data, fn -> cached_data() end)
       |> assign_new(:can_instance_wide, fn -> nil end)}
    end
  end

  def cached_data,
    do:
      (Cache.maybe_apply_cached({Bonfire.Common.Extensions, :data}, []) || [])
      |> Enum.map(fn
        %{app: app} = dep -> Map.put(dep, :extra, Bonfire.Common.ExtensionModule.extension(app))
        dep -> dep
      end)

  def with_extension_info(%{app: app} = dep),
    do: Map.put(dep, :extra, Bonfire.Common.ExtensionModule.extension(app))

  def with_extension_info(dep), do: dep
end
