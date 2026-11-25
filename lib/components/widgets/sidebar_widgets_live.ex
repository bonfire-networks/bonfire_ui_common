defmodule Bonfire.UI.Common.SidebarWidgetsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widgets, :any, required: true
  prop key, :atom, required: true
  prop parent_id, :string, default: nil

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil

  # right sidebar only: the left nav renders this component too, with `key: :main`
  data editable, :any, default: nil

  def render(assigns) do
    assigns
    |> assign(editable: if(assigns.key == :secondary, do: e(assigns.widgets, :editable, nil)))
    |> render_sface()
  end
end
