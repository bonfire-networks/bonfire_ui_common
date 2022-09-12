defmodule Bonfire.UI.Common.LoadMoreLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop live_handler, :string
  prop page_info, :map
  prop target, :any
  prop context, :any

  def unwrap(list) when is_list(list), do: List.first(list)
  def unwrap(other), do: other
end
