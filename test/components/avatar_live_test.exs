defmodule Bonfire.UI.Common.AvatarLiveTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Common.AvatarLive

  describe "generated_avatar_src/2" do
    test "falls back to generated animal avatars when no static paths are configured" do
      # the flavour config may configure paths, explicitly clear for this test
      # (test-env Config.get reads the process tree first)
      Process.put([:bonfire_ui_common, AvatarLive, :generated_avatar_paths], [])

      assert AvatarLive.generated_avatar_src("user-123") == "/gen_avatar/user-123"
    end

    test "deterministically picks a configured static avatar path" do
      avatar_paths = [
        "/images/avatars/jacobin-01.png",
        "/images/avatars/jacobin-02.png",
        "/images/avatars/jacobin-03.png"
      ]

      Process.put(
        [:bonfire_ui_common, AvatarLive, :generated_avatar_paths],
        avatar_paths
      )

      expected = Enum.at(avatar_paths, :erlang.phash2("user-123", length(avatar_paths)))

      assert AvatarLive.generated_avatar_src("user-123") == expected
      assert AvatarLive.generated_avatar_src("user-123") == expected
    end
  end
end
