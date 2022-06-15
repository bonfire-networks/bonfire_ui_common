defmodule Bonfire.UI.Common.UploadButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop uploads, :any
  prop thread_mode, :string
end
