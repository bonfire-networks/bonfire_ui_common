defmodule Bonfire.UI.Common.PageHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :any, default: nil
  prop page_title, :string, required: true
  prop aside, :any, required: false
  prop page_header_drawer, :boolean, default: false
  prop without_header, :boolean, default: false
  slot default
  slot left_action
  slot right_action

end
