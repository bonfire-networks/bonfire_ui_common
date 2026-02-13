defmodule Bonfire.UI.Common.WidgetsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :any, default: nil

  prop widgets, :any, required: true
  prop with_title, :boolean, default: false
  prop with_description, :boolean, default: false
  prop compact, :boolean, default: false
  prop type, :any, default: nil
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar

  prop extra_data, :any, default: %{}

  prop container_class, :css_class, default: nil
  prop wrapper_class, :css_class, default: nil
end
