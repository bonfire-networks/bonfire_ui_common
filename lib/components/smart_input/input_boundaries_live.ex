defmodule Bonfire.UI.Common.InputBoundariesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop create_activity_type, :any, default: nil
  prop preloaded_recipients, :list, default: nil
  prop to_boundaries, :list, default: nil
  prop to_circles, :list, default: nil
  prop showing_within, :any, default: nil
  prop show_select_recipients, :boolean, default: false
  prop open_boundaries, :boolean, default: false
  prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  prop reply_to_id, :string, default: nil
  prop thread_id, :string, default: nil

end
