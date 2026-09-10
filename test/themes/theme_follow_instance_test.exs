defmodule Bonfire.UI.Common.ThemeFollowInstanceTest do
  # async: false because instance-level settings live in the global app Config
  use Bonfire.UI.Common.DataCase, async: false

  alias Bonfire.Common.Config
  alias Bonfire.Common.Settings
  alias Bonfire.Common.Settings.LiveHandler
  alias Bonfire.UI.Common.ThemeHelper

  setup do
    original = Config.get([:ui, :theme], [])
    on_exit(fn -> Config.put([:ui, :theme], original) end)
    :ok
  end

  test "guests get the instance's custom palette when the instance mode is :custom" do
    put_instance_theme(:preferred, :custom)
    put_instance_theme(:custom_instance, %{"color-primary" => "#123456"})

    style = ThemeHelper.custom_theme_style(%{})
    assert style =~ "--color-primary: #123456;"
  end

  test "instance and user custom palettes never mix" do
    put_instance_theme(:preferred, :custom)
    put_instance_theme(:custom_instance, %{"color-primary" => "#123456"})

    user = fake_user!()

    # the user explicitly chooses their own custom theme: only THEIR palette applies
    assert {:ok, %{__context__: %{current_user: user}}} =
             Settings.put([:ui, :theme, :preferred], :custom,
               current_user: user,
               scope: :user
             )

    assert {:ok, %{__context__: %{current_user: user}}} =
             Settings.put_raw([:ui, :theme, :custom, "color-accent"], "#abcdef",
               current_user: user,
               scope: :user
             )

    style = ThemeHelper.custom_theme_style(%{current_user: user})
    assert style =~ "--color-accent: #abcdef;"
    refute style =~ "#123456"
  end

  test "a user's own fixed mode overrides the instance's custom theme" do
    put_instance_theme(:preferred, :custom)
    put_instance_theme(:custom_instance, %{"color-primary" => "#123456"})

    user = fake_user!()

    assert {:ok, %{__context__: %{current_user: user}}} =
             Settings.put([:ui, :theme, :preferred], :light,
               current_user: user,
               scope: :user
             )

    assert ThemeHelper.custom_theme_style(%{current_user: user}) == ""
    assert ThemeHelper.theme_config(%{current_user: user}).mode == :fixed
  end

  test "a user's explicitly empty custom palette does not borrow instance colours" do
    put_instance_theme(:preferred, :custom)
    put_instance_theme(:custom_instance, %{"color-primary" => "#123456"})

    assert {:ok, %{__context__: %{current_user: user}}} =
             Settings.put([:ui, :theme, :preferred], :custom,
               current_user: fake_user!(),
               scope: :user
             )

    assert ThemeHelper.custom_theme_style(%{current_user: user}) == ""
  end

  test "instance palette entries survive the sync into app Config (no atom-lottery discard)" do
    # Theme token keys are deliberately stored as strings (see put_custom_theme_token); the sync
    # into app Config (Config.put_tree, used at boot and on every instance-scope save)
    # must not discard entries whose key has no pre-existing atom in the VM.
    Config.put_tree(
      [
        bonfire: [
          ui: [
            theme: [
              preferred: :custom,
              custom_instance: %{
                "color-base-100" => "#f0dede",
                "color-secondary" => "#34eb4d"
              }
            ]
          ]
        ]
      ],
      already_prepared: true
    )

    palette = Config.get([:ui, :theme, :custom_instance])
    assert palette["color-secondary"] == "#34eb4d"
    assert palette["color-base-100"] == "#f0dede"

    style = ThemeHelper.custom_theme_style(%{})
    assert style =~ "--color-secondary: #34eb4d;"
    assert style =~ "--color-base-100: #f0dede;"
  end

  test "saving an instance palette colour makes it visible to everyone (end to end)" do
    admin = fake_admin!(fake_account!())
    socket = socket(admin)

    assert {:noreply, socket} =
             LiveHandler.handle_event(
               "put_theme",
               %{
                 "keys" => "ui:theme:preferred",
                 "values" => :custom,
                 "scope" => "instance"
               },
               socket
             )

    assert {:noreply, _socket} =
             LiveHandler.handle_event(
               "put_custom_theme_token",
               %{
                 "token" => "color-secondary",
                 "value" => "#34eb4d",
                 "scope" => "instance"
               },
               socket
             )

    # both guests and users who follow the instance see it
    assert ThemeHelper.custom_theme_style(%{}) =~ "--color-secondary: #34eb4d;"

    assert ThemeHelper.custom_theme_style(%{current_user: fake_user!()}) =~
             "--color-secondary: #34eb4d;"
  end

  test "instance mode cascades to users who follow it" do
    put_instance_theme(:preferred, :light)
    put_instance_theme(:instance_theme_light, "instance-light")

    user = fake_user!()

    config = ThemeHelper.theme_config(%{current_user: user})
    assert config.mode == :fixed
    assert config.theme == "instance-light"
  end

  test "an administrator can reset an instance colour and radius individually" do
    socket = fake_account!() |> fake_admin!() |> socket()

    socket =
      Enum.reduce([{"color-primary", "#123456"}, {"radius-box", "1rem"}, {"color-secondary", "#abcdef"}], socket, fn {token, value}, socket ->
        assert {:noreply, socket} =
                 LiveHandler.handle_event("put_custom_theme_token",
                   %{"token" => token, "value" => value, "scope" => "instance"}, socket)
        socket
      end)

    for token <- ["color-primary", "radius-box"] do
      assert {:noreply, _socket} =
               LiveHandler.handle_event("reset_custom_theme_token",
                 %{"token" => token, "scope" => "instance"}, socket)

      tokens = Settings.get([:ui, :theme, :custom_instance], %{}, scope: :instance)
      assert tokens |> Bonfire.Common.Enums.stringify_keys() |> Map.get(token) == nil
    end

    tokens = Settings.get([:ui, :theme, :custom_instance], %{}, scope: :instance)
    assert tokens |> Bonfire.Common.Enums.stringify_keys() |> Map.get("color-secondary") == "#abcdef"
  end

  defp put_instance_theme(key, value) do
    Process.put([:bonfire, :ui, :theme, key], value)
  end

  defp socket(user) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        __context__: %{current_user: user},
        current_user: user,
        flash: %{}
      }
    }
  end
end
