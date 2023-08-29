defmodule Bonfire.UI.Common.InstanceSidebarSettingsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop id, :string, default: nil
  prop page, :string, default: nil

  declare_nav_component("Links to sections of instance settings")

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
