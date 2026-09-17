defmodule Bonfire.UI.Common.CaretIconsTest do
  use ExUnit.Case, async: true

  doctest Iconify, only: [resolve_icon_weight: 4]

  test "Bonfire excludes filled caret weights while preserving other icons" do
    for direction <- ~w(right left down up), weight <- ~w(fill duotone) do
      icon = "caret-#{direction}-#{weight}"
      assert Iconify.resolve_icon_weight("ph", icon, %{}) == icon
      assert Iconify.resolve_icon_weight("ph", icon) == "caret-#{direction}"
    end

    assert Iconify.resolve_icon_weight("ph", "caret-right-bold") == "caret-right-bold"
    assert Iconify.resolve_icon_weight("ph", "heart-fill") == "heart-fill"
    assert Iconify.resolve_icon_weight("other", "caret-right-fill") == "caret-right-fill"
  end
end
