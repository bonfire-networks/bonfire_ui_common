defmodule Bonfire.UI.Common.PageHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Title to show in header. Only used if no default slot is set"
  prop page_title, :string, default: nil
  # prop selected_tab, :string, default: nil
  # prop page, :string, default: nil
  prop back, :boolean, default: false, required: false
  # prop transparent_header, :boolean, default: false
  prop page_header_icon, :string, default: nil
  prop extra, :string, default: nil
  # prop showing_within, :atom, default: nil

  slot default
  slot left_action
  slot breadcrumbs
  slot right_action
end
