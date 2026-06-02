defmodule Bonfire.UI.Common.CustomThemeSaveTest do
  @moduledoc """
  Covers the custom-theme colour storage guarantees behind the `put_custom_color`
  LiveHandler (see issue #1747): each colour is saved non-destructively under a
  consistent string key, so setting one colour never resets another and `-content`
  variants don't collide with their base colour. Also checks that the custom palette
  is emitted (for `<html>`) only when the active theme is `:custom`.
  """
  use Bonfire.UI.Common.DataCase, async: true

  alias Bonfire.Common.Settings
  alias Bonfire.Common.Enums
  alias Bonfire.UI.Common.ThemeHelper

  setup do
    {:ok, user: fake_user!()}
  end

  # mirrors what the `put_custom_color` handler does: a single non-destructive
  # `put_raw` of one colour, threading the updated context (as the live socket would).
  defp put_color!(user, key, value) do
    assert {:ok, %{__context__: %{current_user: updated}}} =
             Settings.put_raw([:ui, :theme, :custom, key], value, current_user: user)

    updated
  end

  defp colour(user, key) do
    Settings.get([:ui, :theme, :custom], %{}, current_user: user)
    |> Enums.stringify_keys()
    |> Map.get(key)
  end

  describe "saving custom theme colours" do
    test "setting a second colour does not reset the first", %{user: user} do
      user = put_color!(user, "color-base-100", "#ff0000")
      user = put_color!(user, "color-base-200", "#0000ff")

      assert colour(user, "color-base-100") == "#ff0000"
      assert colour(user, "color-base-200") == "#0000ff"
    end

    test "a -content variant is stored under its own key, not its base colour", %{user: user} do
      user = put_color!(user, "color-primary", "#111111")
      user = put_color!(user, "color-primary-content", "#eeeeee")

      assert colour(user, "color-primary") == "#111111"
      assert colour(user, "color-primary-content") == "#eeeeee"
    end

    test "base-content is stored independently of base-100", %{user: user} do
      user = put_color!(user, "color-base-100", "#ffffff")
      user = put_color!(user, "color-base-content", "#000000")

      assert colour(user, "color-base-100") == "#ffffff"
      assert colour(user, "color-base-content") == "#000000"
    end

    test "keys are stored consistently (one entry per colour after stringifying)", %{user: user} do
      user = put_color!(user, "color-base-100", "#ff0000")
      user = put_color!(user, "color-base-100", "#00ff00")

      custom =
        Settings.get([:ui, :theme, :custom], %{}, current_user: user)
        |> Enums.stringify_keys()

      assert custom["color-base-100"] == "#00ff00"
      assert Enum.count(Map.keys(custom), &(&1 == "color-base-100")) == 1
    end
  end

  describe "custom_theme_style/1" do
    test "emits only the colours the user set (not defaults) when preferred is :custom", %{
      user: user
    } do
      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :preferred], :custom, current_user: user)

      user = put_color!(user, "color-base-content", "#123456")

      css = ThemeHelper.custom_theme_style(%{current_user: user})

      assert css =~ "--color-base-content: #123456;"
      # unset variables are NOT emitted, so they fall through to the base theme
      refute css =~ "--color-base-100:"
    end

    test "returns an empty string when preferred is not :custom", %{user: user} do
      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :preferred], :dark, current_user: user)

      assert ThemeHelper.custom_theme_style(%{current_user: user}) == ""
    end
  end

  describe "user vs instance isolation" do
    test "custom_theme_style/1 falls back to :custom_instance when :custom is empty", %{
      user: user
    } do
      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :preferred], :custom, current_user: user)

      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put_raw([:ui, :theme, :custom_instance, "color-base-content"], "#abcabc",
                 current_user: user
               )

      css = ThemeHelper.custom_theme_style(%{current_user: user})
      assert css =~ "--color-base-content: #abcabc;"
    end

    test "custom_theme_style/1 prefers the user's :custom over :custom_instance", %{user: user} do
      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :preferred], :custom, current_user: user)

      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put_raw([:ui, :theme, :custom_instance, "color-base-content"], "#abcabc",
                 current_user: user
               )

      user = put_color!(user, "color-base-content", "#123123")

      css = ThemeHelper.custom_theme_style(%{current_user: user})
      assert css =~ "--color-base-content: #123123;"
      refute css =~ "#abcabc"
    end
  end
end
