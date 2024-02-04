defmodule Bonfire.UI.Common.SidebarSettingsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop id, :string, default: nil
  prop showing_within, :atom, default: :settings

  declare_nav_component("Links to sections of settings")
  # exclude_from_nav: true

  def render(assigns) do
    assigns
    |> update(:id, fn
      nil -> assigns[:__context__][:current_params]["id"]
      id -> id
    end)
    # |> debug()
    |> render_sface()
  end
end
