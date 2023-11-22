defmodule Bonfire.UI.Common.UploadButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop uploads, :any, default: nil
  prop uploaded_files, :list, default: []

  defp upload_error_to_string(:too_large), do: "The file is too large"
end
