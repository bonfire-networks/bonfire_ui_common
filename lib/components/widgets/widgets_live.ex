defmodule Bonfire.UI.Common.WidgetsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widgets, :any, required: true
  prop with_title, :boolean, default: false

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar
  prop extra_data, :any, default: %{}
end
