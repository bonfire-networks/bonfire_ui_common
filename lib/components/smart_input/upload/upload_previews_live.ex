defmodule Bonfire.UI.Common.UploadPreviewsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop uploads, :any
  prop parent_id, :any, default: nil
  prop event_target, :any, default: nil
  prop selected_cover, :any, default: nil

  def error_to_string(:too_large), do: Bonfire.Fail.get_error_msg(:file_too_large)
  def error_to_string(:not_accepted), do: Bonfire.Fail.get_error_msg(:file_type_not_allowed)
  def error_to_string(error) when is_atom(error), do: Bonfire.Fail.get_error_msg(error)
end
