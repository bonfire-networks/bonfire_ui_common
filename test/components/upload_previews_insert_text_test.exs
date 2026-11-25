defmodule Bonfire.UI.Common.UploadPreviewsInsertTextTest do
  @moduledoc "What placing a picked media in the text writes: a file is an `![](url)` image, a link preview (even one with a video or audio player) is its URL."

  use Bonfire.UI.Common.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.UI.Common.UploadPreviewsLive

  defp media(type, url),
    do: struct(Bonfire.Files.Media, id: "01HZZ0InsertTextTEST", media_type: type, path: url)

  test "an image, video or audio file is written as markdown" do
    for type <- ["image/png", "video/mp4", "audio/mpeg"] do
      url = "https://example.com/file"
      assert UploadPreviewsLive.insert_text(media(type, url)) == "![](#{url})"
    end
  end

  test "a link preview, with a player or not, is written as its URL" do
    for type <- ["video/embed", "audio/embed", "link", "research"] do
      url = "https://example.com/a-page"
      assert UploadPreviewsLive.insert_text(media(type, url)) == url
    end
  end
end
