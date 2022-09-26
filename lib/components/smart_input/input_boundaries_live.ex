defmodule Bonfire.UI.Common.InputBoundariesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop create_object_type, :atom, default: nil
  prop preloaded_recipients, :list, default: nil
  prop to_boundaries, :list, default: nil
  prop to_circles, :list, default: []
  prop showing_within, :any, default: nil
  prop show_select_recipients, :boolean, default: false
  prop open_boundaries, :boolean, default: false
  prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  prop reply_to_id, :string, default: nil
  prop context_id, :string, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
end
