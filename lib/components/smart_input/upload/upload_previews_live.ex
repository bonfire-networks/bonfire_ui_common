defmodule Bonfire.UI.Common.UploadPreviewsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop uploads, :any
  prop parent_id, :any, default: nil
  prop event_target, :any, default: nil
  prop selected_cover, :any, default: nil
  # files picked from the author's own media, each as `picked_entry/1` gives it
  prop picked_media, :list, default: []

  @doc "A picked `media` as the composer keeps it (a plain map, since its options are encoded as JSON): its id, type, name, alt text, preview URL, what placing it in the text writes, and how many objects use it already (one count query)."
  def picked_entry(media) do
    %{
      id: id(media),
      media_type: e(media, :media_type, nil),
      name:
        Bonfire.Common.Utils.maybe_apply(Bonfire.Files.Media, :media_label, [media],
          fallback_return: nil
        ) || Path.basename(e(media, :path, "") || ""),
      alt: e(media, :metadata, "alt", nil),
      thumbnail_url: Bonfire.Common.Media.media_url(media),
      insert_text: insert_text(media),
      object_count:
        Bonfire.Common.Utils.maybe_apply(Bonfire.Files, :attachments_count, [media],
          fallback_return: 0
        )
    }
  end

  @doc "What placing `media` in the text writes at the cursor: an image, video or audio file as `![](url)`, anything else (eg. a link's player) as its URL, at its `Bonfire.Files.inline_url/1`."
  def insert_text(media) do
    url =
      Bonfire.Common.Utils.maybe_apply(Bonfire.Files, :inline_url, [media], fallback_return: nil)

    cond do
      is_nil(url) ->
        nil

      String.starts_with?(e(media, :media_type, "") || "", ["image", "video", "audio"]) ->
        "![](#{url})"

      true ->
        url
    end
  end

  @doc "The ids of the picked files, comma-separated, as the picker's and the previews' buttons send them along (their events don't get the composer's state)."
  def picked_ids(picked_media), do: picked_media |> List.wrap() |> Enum.map_join(",", &id/1)

  @doc "The note by a picked file's alt text when other posts use it too, since its alt text belongs to the file."
  def shared_alt_note(media) do
    case e(media, :object_count, 0) do
      count when is_integer(count) and count > 0 ->
        l("Also changes it in %{count} other posts", count: count)

      _ ->
        nil
    end
  end

  def error_to_string(:too_large), do: Bonfire.Fail.get_error_msg(:file_too_large)
  def error_to_string(:not_accepted), do: Bonfire.Fail.get_error_msg(:file_type_not_allowed)
  def error_to_string(error) when is_atom(error), do: Bonfire.Fail.get_error_msg(error)
end
