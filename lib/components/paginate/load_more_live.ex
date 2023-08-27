defmodule Bonfire.UI.Common.LoadMoreLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop live_handler, :string
  prop page_info, :any, default: nil
  prop target, :any, default: nil
  prop context, :any, default: nil
  prop entry_count, :any, default: nil
  prop label, :any, default: nil

  prop infinite_scroll, :any, default: false
  prop hide_load_more, :boolean, default: false

  prop opts, :map, default: %{}

  slot if_no_more

  def render(assigns) do
    assigns
    |> assign(:cursor, unwrap(e(assigns.page_info, :end_cursor, nil)))
    |> render_sface()
  end

  def unwrap(list) when is_list(list), do: List.first(list)
  def unwrap(other), do: other
end
