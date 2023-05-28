defmodule Bonfire.UI.Common.LoadMoreLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop live_handler, :string
  prop page_info, :map
  prop target, :any
  prop context, :any
  prop entry_count, :any, default: nil
  prop infinite_load, :boolean, default: false

  def unwrap(list) when is_list(list), do: List.first(list)
  def unwrap(other), do: other
end
