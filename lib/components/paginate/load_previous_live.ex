defmodule Bonfire.UI.Common.LoadPreviousLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop live_handler, :string
  prop page_info, :map
  prop target, :any
  prop context, :any

  def render(assigns) do
    assigns
    |> assign(:cursor, unwrap(e(assigns.page_info, :start_cursor, nil)))
    |> render_sface()
  end

  def unwrap(list) when is_list(list), do: List.first(list)
  def unwrap(other), do: other
end
