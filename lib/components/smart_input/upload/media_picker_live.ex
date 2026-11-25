defmodule Bonfire.UI.Common.MediaPickerLive do
  @moduledoc """
  The composer's media picker: a drawer listing the author's own media (the `:my_media` feed, last used first) as tiles, each with Insert (places it in the text at the cursor, and adds it to the uploads) and Attach (only adds it). Opened by the "Your media" button among the composer's controls (see `Bonfire.UI.Common.InputControlsLive`).

  Beside the centred composer, against its right edge, taking the room up to the window's margin when there's room for two tiles, else over the composer's right part; full screen on small screens. Outside the composer's own box, so it isn't clipped by it.

  Its Filters toggle shows the feed's own filters (`Bonfire.UI.Social.WidgetCustomizeFeedLive`, as the events page does), with the media type row on top.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_opts, :map, default: %{}
  prop event_target, :any, default: nil

  # the feed's id, which the filters apply to
  @feed_id "media_picker_feed"
  def feed_id, do: @feed_id

  @doc "The picker feed's filters: the author's own files (`media_has_file`: a link preview or an embed they posted isn't one, whichever media type is picked), last used first."
  def feed_filters(context),
    do: %{creators: [current_user_id(context)], sort_by: :last_used, media_has_file: true}

  # what doesn't apply to a list of one's own files: whose they are, replies, boosts and the like, and the kinds of object or activity
  @hidden_filters [
    :origin,
    :hide_own,
    :from_people,
    :not_people,
    :hashtags,
    :time_range,
    :happening,
    :object_types,
    :activity_types,
    :subject_types,
    :circles,
    :save_preset,
    :replies,
    :boosts,
    :group_activity
  ]

  @doc "The props of the feed's filters (`Bonfire.UI.Social.WidgetCustomizeFeedLive`): the media type row on top, the kinds of one's own files (no links), not saved."
  def filters_props(context) do
    [
      id: "media_picker_filters_widget",
      feed_name: :my_media,
      feed_filters: feed_filters(context),
      event_target: "#" <> @feed_id,
      can_save: false,
      hide_filters: @hidden_filters,
      top_sections: [:media_types],
      media_types: [:image, :video, :audio, :document]
    ]
  end
end
