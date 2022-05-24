defmodule Bonfire.UI.Common.InputControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils

  # prop target_component, :string
  prop reply_to_id, :string
  prop thread_id, :string
  prop create_activity_type, :any
  prop to_circles, :list
  prop showing_within, :any
  prop with_rich_editor, :boolean, default: true, required: false
  prop uploads, :any
  prop uploaded_files, :list
  prop thread_mode, :string

end
