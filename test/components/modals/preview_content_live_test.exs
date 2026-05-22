defmodule Bonfire.UI.Common.PreviewContentLiveTest do
  use Bonfire.UI.Common.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  alias Bonfire.UI.Common.OpenPreviewLive
  alias Bonfire.UI.Common.PreviewContentLive

  describe "OpenPreviewLive.external_url?/1" do
    test "allows relative and web URLs to use the preview modal" do
      refute OpenPreviewLive.external_url?("/post/01TEST")
      refute OpenPreviewLive.external_url?("http://example.test/post/01TEST")
      refute OpenPreviewLive.external_url?("https://example.test/post/01TEST")
    end

    test "suppresses non-web protocols" do
      assert OpenPreviewLive.external_url?("ap-mls://room/01TEST")
      assert OpenPreviewLive.external_url?("mailto:test@example.test")
    end
  end

  describe "PreviewContentLive.reset_loaded/1" do
    test "marks keyword modal assigns as not loaded" do
      assigns = PreviewContentLive.reset_loaded(object_id: "01TEST", loaded: true)

      assert Keyword.fetch!(assigns, :object_id) == "01TEST"
      assert Keyword.fetch!(assigns, :loaded) == false
    end

    test "marks map modal assigns as not loaded" do
      assert %{object_id: "01TEST", loaded: false} =
               PreviewContentLive.reset_loaded(%{object_id: "01TEST", loaded: true})
    end

    test "falls back to keyword assigns for unexpected modal assign shapes" do
      assert [loaded: false] = PreviewContentLive.reset_loaded(nil)
    end
  end
end
