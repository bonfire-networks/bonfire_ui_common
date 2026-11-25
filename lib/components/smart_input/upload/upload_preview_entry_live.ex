defmodule Bonfire.UI.Common.UploadPreviewEntryLive do
  @moduledoc """
  One file among the composer's uploads (see `Bonfire.UI.Common.UploadPreviewsLive`): its thumbnail, name, alt text field and actions (insert in the text, remove), in the strip of thumbnails or the expanded list. The same row for a file being uploaded and for one picked from the author's own media; what differs comes in as props and slots.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop dom_id, :string, required: true
  # an upload's entry ref, or a picked file's `Media` id (one of them)
  prop ref, :string, default: nil
  prop media_id, :string, default: nil

  # its MIME type, which decides the thumbnail (and whether an image takes the full width while its alt text is written)
  prop type, :string, default: ""
  prop name, :string, default: nil
  prop errors, :list, default: []
  prop progress, :any, default: nil
  prop alt_name, :string, required: true
  prop alt_value, :string, default: nil
  # eg. that other posts use the file too, so an alt text changed here changes there
  prop alt_note, :string, default: nil
  # what "Insert in text" places at the cursor; no button without it
  prop insert_text, :string, default: nil
  prop remove_event, :string, required: true
  prop remove_role, :string, default: nil

  # for a picked file: the ids picked, sent with Remove (as `picked`), since its event doesn't get the composer's state
  prop picked, :string, default: nil
  prop event_target, :any, default: nil
  # the upload chosen as the cover (its badge in the strip)
  prop cover?, :boolean, default: false

  # an image's preview; else an icon for its type is shown
  slot thumbnail
  # more actions next to Insert and Remove (eg. Set as cover)
  slot actions
  # hidden inputs sent with the form
  slot hidden

  def image?(type), do: String.starts_with?(type || "", "image")

  @doc "How a file of this MIME type shows in its row: `\"image\"` (its thumbnail), else `\"pdf\"`, `\"video\"`, `\"audio\"` or `\"document\"` (an icon for that type)"
  def preview_kind(type) do
    type = type || ""

    cond do
      image?(type) -> "image"
      String.contains?(type, "pdf") -> "pdf"
      String.starts_with?(type, "video") -> "video"
      String.starts_with?(type, "audio") -> "audio"
      true -> "document"
    end
  end
end
