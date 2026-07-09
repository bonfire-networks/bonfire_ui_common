defmodule Bonfire.UI.Common.ThemeHelperTest do
  use Bonfire.UI.Common.DataCase, async: true

  alias Bonfire.Common.Settings
  alias Bonfire.Common.Settings.LiveHandler
  alias Bonfire.UI.Common.ThemeHelper

  doctest ThemeHelper, import: true

  describe "resolve_theme_config/3" do
    test ":light is fixed and resolves to the light theme name" do
      assert %{mode: :fixed, theme: "lite"} =
               ThemeHelper.resolve_theme_config(:light, "lite", "drk")
    end

    test ":dark is fixed and resolves to the dark theme name" do
      assert %{mode: :fixed, theme: "drk"} =
               ThemeHelper.resolve_theme_config(:dark, "lite", "drk")
    end

    test ":custom is fixed on the configured dark/base theme" do
      assert %{mode: :fixed, theme: "drk"} =
               ThemeHelper.resolve_theme_config(:custom, "lite", "drk")
    end

    test ":system follows the device and exposes both theme names (dark = no-JS fallback)" do
      assert %{mode: :system, theme: "drk", light: "lite", dark: "drk"} =
               ThemeHelper.resolve_theme_config(:system, "lite", "drk")
    end

    test "unknown preference falls back to a fixed dark theme" do
      assert %{mode: :fixed, theme: "drk"} =
               ThemeHelper.resolve_theme_config(:bogus, "lite", "drk")
    end
  end

  describe "theme_config/1 with no user settings (instance defaults)" do
    test "defaults to :system mode, with the dark theme as the no-JS/SSR fallback" do
      config = ThemeHelper.theme_config(%{})

      assert config.mode == :system
      assert config.theme == config.dark
      assert is_binary(config.light)
      assert is_binary(config.dark)
    end

    test "current_theme/1 returns the concrete fallback name from theme_config/1" do
      assert ThemeHelper.current_theme(%{}) == ThemeHelper.theme_config(%{}).theme
    end
  end

  describe "theme_config/1 with user theme settings" do
    test "uses the user's configured light theme when light mode is active" do
      user = fake_user!()

      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :preferred], :light,
                 current_user: user,
                 scope: :user
               )

      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :instance_theme_light], "user-light",
                 current_user: user,
                 scope: :user
               )

      config = ThemeHelper.theme_config(%{current_user: user})

      assert config.mode == :fixed
      assert config.light == "user-light"
      assert config.theme == "user-light"
    end
  end

  describe "put_theme handler" do
    test "normalises an atomised user light theme before pushing it" do
      user = fake_user!()

      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put([:ui, :theme, :preferred], :light,
                 current_user: user,
                 scope: :user
               )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          __context__: %{current_user: user},
          current_user: user,
          flash: %{}
        }
      }

      assert {:noreply, socket} =
               LiveHandler.handle_event(
                 "put_theme",
                 %{
                   "keys" => "ui:theme:instance_theme_light",
                   "values" => "light",
                   "scope" => "user"
                 },
                 socket
               )

      config = ThemeHelper.theme_config(socket)

      assert config.mode == :fixed
      assert config.light == "light"
      assert config.theme == "light"
    end
  end

  describe "custom_theme_style/1 with no user (instance default)" do
    test "returns an empty string when the active theme is not :custom" do
      # instance default preference is :system, so no custom palette is emitted
      assert ThemeHelper.custom_theme_style(%{}) == ""
    end
  end

  describe "custom_theme_key/1" do
    test "instance scope maps to the :custom_instance key (atom or string)" do
      assert ThemeHelper.custom_theme_key(:instance) == :custom_instance
      assert ThemeHelper.custom_theme_key("instance") == :custom_instance
    end

    test "user and any other scope map to the :custom key" do
      assert ThemeHelper.custom_theme_key(:user) == :custom
      assert ThemeHelper.custom_theme_key("user") == :custom
      assert ThemeHelper.custom_theme_key(nil) == :custom
    end
  end
end
