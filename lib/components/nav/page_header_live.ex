defmodule Bonfire.UI.Common.PageHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :any
  prop page_title, :string, required: true
  slot default
  slot left_action
end
