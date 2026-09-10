defmodule DaisyThemeTest do
  use ExUnit.Case, async: true

  @moduletag :ui

  describe "style_attr_overrides/1" do
    test "emits only recognised overrides without filling unset values" do
      assert DaisyTheme.style_attr_overrides(%{
               "color-base-content" => "#123456",
               "not-a-real-key" => "#ffffff"
             }) == "--color-base-content: #123456;"
    end

    test "accepts atom keys from historical settings" do
      assert DaisyTheme.style_attr_overrides(%{"color-primary": "#abcdef"}) ==
               "--color-primary: #abcdef;"
    end

    test "returns no declarations for an empty palette" do
      assert DaisyTheme.style_attr_overrides(%{}) == ""
    end

    test "normalises legacy bare hex values" do
      assert DaisyTheme.style_attr_overrides(%{"color-base-200" => "fff"}) ==
               "--color-base-200: #fff;"
    end

    test "drops values that could escape a CSS declaration" do
      for unsafe <- [
            "fff; --color-primary: red",
            "red}",
            "{",
            ""
          ] do
        assert DaisyTheme.style_attr_overrides(%{"color-base-100" => unsafe}) == ""
      end
    end
  end

  describe "normalize_value/2" do
    test "normalises the opaque hex lengths supported by the picker" do
      for {input, expected} <- [
            {"abc", "#abc"},
            {"abcdef", "#abcdef"},
            {"#ABCDEF", "#ABCDEF"}
          ] do
        assert DaisyTheme.normalize_value("color-primary", input) == {:ok, expected}
      end
    end

    test "rejects alpha hex values that the picker cannot preserve" do
      assert DaisyTheme.normalize_value("color-primary", "abcd") == :error
      assert DaisyTheme.normalize_value("color-primary", "#abcdef12") == :error
    end

    test "accepts adapted-theme colour functions such as OKLCH" do
      assert DaisyTheme.normalize_value("color-primary", "oklch(66% 0.08 230)") ==
               {:ok, "oklch(66% 0.08 230)"}
    end

    test "converts integer colours only inside the RGB range" do
      assert DaisyTheme.normalize_value("color-primary", 0) == {:ok, "#000000"}
      assert DaisyTheme.normalize_value("color-primary", 16_777_215) == {:ok, "#FFFFFF"}
      assert DaisyTheme.normalize_value("color-primary", -1) == :error
      assert DaisyTheme.normalize_value("color-primary", 16_777_216) == :error
    end

    test "accepts safe shape tokens" do
      assert DaisyTheme.normalize_value("radius-box", "0.5rem") == {:ok, "0.5rem"}
      assert DaisyTheme.normalize_value(:depth, 1) == {:ok, "1"}
      assert DaisyTheme.normalize_value(:noise, 0.5) == {:ok, "0.5"}
    end

    test "rejects unknown keys, invalid types and declaration breakers" do
      assert DaisyTheme.normalize_value("not-a-real-key", "#ffffff") == :error
      assert DaisyTheme.normalize_value("color-primary", nil) == :error
      assert DaisyTheme.normalize_value("radius-box", "1rem;") == :error
    end
  end
end
