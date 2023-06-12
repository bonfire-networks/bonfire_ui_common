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
  prop selected_tab, :string

  def render(assigns) do
    assigns
    |> assign_new(:data, fn -> Bonfire.Common.Extensions.data() end)
    |> assign_new(:can_instance_wide, fn ->
      Bonfire.Boundaries.can?(assigns, :toggle, :instance)
    end)
    |> assign_new(:required_deps, fn -> Bonfire.Application.required_deps() end)
    |> render_sface()
  end
end
