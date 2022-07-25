defmodule Bonfire.UI.Common.InputControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils

  # prop target_component, :string
  prop reply_to_id, :string, default: nil
  prop thread_id, :string, default: nil
  prop create_activity_type, :any, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: nil
  prop showing_within, :any, default: nil
  prop uploads, :any, default: nil
  prop uploaded_files, :list, default: []
  prop thread_mode, :atom, default: nil
  prop page, :any, default: nil

end
