defmodule Bonfire.UI.Common.LoadPreviousLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop live_handler, :any, default: nil
  prop page_info, :any, default: nil
  prop target, :any, default: nil
  prop context, :any, default: nil

  def render(assigns) do
    assigns
    |> assign(:cursor, unwrap(e(assigns.page_info, :start_cursor, nil)))
    |> render_sface()
  end

  def unwrap(list) when is_list(list), do: List.first(list)
  def unwrap(other), do: other
end
