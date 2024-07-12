defmodule Bonfire.UI.Common.ExtraDepsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.Common.Extensions

  prop scope, :any, default: nil

  # prop feature_extensions, :list, default: []
  prop ui, :list, default: []
  prop schemas, :list, default: []
  prop ecosystem_libs, :list, default: []
  prop other_deps, :list, default: []

  prop settings_section_title, :string, default: "Data Schema & Libraries"

  def render(assigns) do
    if socket_connected?(assigns) do
      assigns
      |> assign_new(:data, fn -> cached_data() end)
      |> assign_new(:can_instance_wide, fn ->
        Bonfire.Boundaries.can?(assigns[:__context__], :toggle, :instance)
      end)
      |> render_sface()
    else
      assigns
      |> assign_new(:data, fn ->
        []
        cached_data()
      end)
      |> assign_new(:can_instance_wide, fn -> nil end)
      |> render_sface()
    end
  end

  def cached_data, do: Cache.maybe_apply_cached({Bonfire.Common.Extensions, :data}, [])
end
