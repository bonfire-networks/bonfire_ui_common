defmodule Bonfire.UI.Common.PageHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Title to show in header. Only used if no default slot is set"
  prop page_title, :string, default: nil
  prop back, :boolean, default: false, required: false
  prop page_header_drawer, :boolean, default: false
  prop showing_within, :string, default: nil
  
  slot default
  slot left_action
  slot breadcrumbs
  slot right_action
end
