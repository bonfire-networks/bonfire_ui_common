defmodule DaisyThemeTest do
  use ExUnit.Case, async: true

  describe "default_theme/0" do
    test "includes base-content (the text colour) as a settable string key" do
      assert %{"color-base-content" => "#" <> _} = DaisyTheme.default_theme()
    end

    test "uses string keys throughout (the canonical custom-theme key type)" do
      assert Enum.all?(Map.keys(DaisyTheme.default_theme()), &is_binary/1)
    end
  end

  describe "style_attr/1" do
    test "emits all theme CSS variables, including --color-base-content" do
      css = DaisyTheme.style_attr(%{})

      assert css =~ "--color-base-content:"
      assert css =~ "--color-base-100:"
      assert css =~ "--color-primary:"
      assert css =~ "--color-primary-content:"
      assert css =~ "--radius-box:"
    end

    test "a custom value overrides the default (string-keyed)" do
      css = DaisyTheme.style_attr(%{"color-base-100" => "#abcdef"})
      assert css =~ "--color-base-100: #abcdef;"
    end

    test "custom base-content overrides the default text colour" do
      css = DaisyTheme.style_attr(%{"color-base-content" => "#123456"})
      assert css =~ "--color-base-content: #123456;"
    end

    test "content variants are emitted independently of their base colour" do
      css = DaisyTheme.style_attr(%{"color-primary" => "#111111", "color-primary-content" => "#eeeeee"})

      assert css =~ "--color-primary: #111111;"
      assert css =~ "--color-primary-content: #eeeeee;"
    end
  end

  describe "style_attr_overrides/1" do
    test "emits only the variables present in config (no merged defaults)" do
      css = DaisyTheme.style_attr_overrides(%{"color-base-content" => "#123456"})

      assert css =~ "--color-base-content: #123456;"
      # unset variables fall through to the base theme, so they're NOT emitted
      refute css =~ "--color-base-100:"
      refute css =~ "--color-primary:"
    end

    test "returns an empty string for an empty palette" do
      assert DaisyTheme.style_attr_overrides(%{}) == ""
    end

    test "ignores unrecognised keys" do
      assert DaisyTheme.style_attr_overrides(%{"not-a-real-key" => "#fff"}) == ""
    end
  end

  describe "generate/1" do
    test "ignores keys that aren't recognised theme variables" do
      generated = DaisyTheme.generate(%{"not-a-real-key" => "#fff"})

      refute Enum.any?(generated, &(&1.name == "not-a-real-key"))
      # but still includes the known defaults (merged in)
      assert Enum.any?(generated, &(&1.name == "color-base-content"))
    end
  end
end
