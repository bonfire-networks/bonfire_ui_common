defmodule Bonfire.UI.Common.MediaPickerLive do
  @moduledoc """
  The composer's media picker: the author's own media (the `:my_media` feed, last used first), each with Insert (placed in the text at the cursor, and added to the uploads) and Attach (only added). Opened by "Your media" among the composer's controls (`Bonfire.UI.Common.InputControlsLive`); closed by its button, by Esc, or when the composer is minimised.

  A panel against the window's right edge, in the room right of the centred composer, so it never covers the text being written; when that room is short the composer narrows instead (app.css). A full-width sheet on small screens and over a fullscreen composer. The tiles are `Bonfire.UI.Social.Activity.MediaTileLive`'s picker mode; the type pills send the feed's own `set_filter`, as `Bonfire.UI.Social.TabFilterButtonsLive` does.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_opts, :map, default: %{}
  prop event_target, :any, default: nil

  @feed_id "media_picker_feed"
  @doc "The picker feed's DOM id, which the type pills target."
  def feed_id, do: @feed_id

  @doc "The picker feed's filters: the author's own files (`media_has_file`: a link preview or an embed they posted isn't one, whichever media type is picked), last used first."
  def feed_filters(context),
    do: %{creators: [current_user_id(context)], sort_by: :last_used, media_has_file: true}

  @doc "The media type pills, as `{toggle_type, label}`. All sends the `my_media` preset's own `attachment`: no type at all would end the feed's one-row-per-media mode."
  def media_type_pills,
    do: [
      {"attachment", l("All")},
      {"image", l("Images")},
      {"video", l("Video")},
      {"audio", l("Audio")},
      {"document", l("Documents")}
    ]
end
