defmodule Bonfire.UI.Common.ExtensionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop scope, :any, default: nil

  prop feature_extensions, :list, default: []
  prop ui, :list, default: []
  prop schemas, :list, default: []
  prop ecosystem_libs, :list, default: []
  prop other_deps, :list, default: []

  prop get_link, :any
  prop settings_section_title, :string, default: "Bonfire extensions"

  def render(assigns) do
    if socket_connected?(assigns) do
      assigns
      |> assign_new(:data, fn -> Bonfire.Common.Extensions.data() end)
      |> assign_new(:can_instance_wide, fn ->
        Bonfire.Boundaries.can?(assigns[:__context__], :toggle, :instance)
      end)
      |> assign_new(:required_deps, fn -> Bonfire.Application.required_deps() end)
      |> render_sface()
    else
      assigns
      |> assign_new(:data, fn -> [] end)
      |> assign_new(:can_instance_wide, fn -> nil end)
      |> assign_new(:required_deps, fn -> [] end)
      |> render_sface()
    end
  end
end
