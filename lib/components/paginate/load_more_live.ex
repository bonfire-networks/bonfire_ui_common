defmodule Bonfire.UI.Common.LoadMoreLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_info, :any, default: nil
  prop cursor, :any, default: nil
  prop limit, :any, default: nil
  prop multiply_limit, :any, default: nil

  prop live_handler, :string
  prop target, :any, default: nil
  prop context, :any, default: nil
  prop entry_count, :any, default: nil
  prop label, :any, default: nil

  prop infinite_scroll, :any, default: false
  prop hide_load_more, :boolean, default: false
  prop hide_if_no_more, :boolean, default: false
  prop hide_guest_fallback, :boolean, default: false

  prop opts, :map, default: %{}

  slot if_no_more

  def render(assigns) do
    assigns
    |> assign(:cursor, assigns[:cursor] || end_cursor(assigns[:page_info]))
    |> render_sface()
  end

  def end_cursor(page_info) do
    unwrap(e(page_info, :end_cursor, nil))
  end

  def unwrap(list) when is_list(list), do: List.first(list)
  def unwrap(other), do: other
end
