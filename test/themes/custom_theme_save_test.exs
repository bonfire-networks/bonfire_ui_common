defmodule Bonfire.UI.Common.CustomThemeSaveTest do
  @moduledoc "Tests the custom-theme LiveHandler contract through its public events."
  use Bonfire.UI.Common.DataCase, async: true

  alias Bonfire.Common.Enums
  alias Bonfire.Common.Settings
  alias Bonfire.Common.Settings.LiveHandler

  setup do
    user = fake_user!()
    {:ok, socket: socket(user)}
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

  defp put_token!(socket, token, value) do
    assert {:noreply, socket} =
             LiveHandler.handle_event(
               "put_custom_theme_token",
               %{
                 "token" => token,
                 "value" => value,
                 "scope" => "user"
               },
               socket
             )

    socket
  end

  defp reset_token!(socket, token) do
    assert {:noreply, socket} =
             LiveHandler.handle_event(
               "reset_custom_theme_token",
               %{"token" => token, "scope" => "user"},
               socket
             )

    socket
  end

  defp custom_theme(socket) do
    Settings.get([:ui, :theme, :custom], %{}, current_user: socket.assigns.current_user)
    |> Enums.stringify_keys()
  end

  describe "put_custom_theme_token" do
    test "preserves existing colours when another colour is saved", %{socket: socket} do
      socket = put_token!(socket, "color-base-100", "#ff0000")
      socket = put_token!(socket, "color-base-200", "#0000ff")

      assert custom_theme(socket) == %{
               "color-base-100" => "#ff0000",
               "color-base-200" => "#0000ff"
             }
    end

    test "stores content colours independently from their surfaces", %{socket: socket} do
      socket = put_token!(socket, "color-primary", "#111111")
      socket = put_token!(socket, "color-primary-content", "#eeeeee")
      socket = put_token!(socket, "color-base-100", "#ffffff")
      socket = put_token!(socket, "color-base-content", "#000000")

      assert custom_theme(socket) == %{
               "color-primary" => "#111111",
               "color-primary-content" => "#eeeeee",
               "color-base-100" => "#ffffff",
               "color-base-content" => "#000000"
             }
    end

    test "replaces a repeated colour without emitting duplicate declarations", %{socket: socket} do
      socket = put_token!(socket, "color-base-100", "#ff0000")
      socket = put_token!(socket, "color-base-100", "#00ff00")

      css = socket |> custom_theme() |> DaisyTheme.style_attr_overrides()

      assert custom_theme(socket)["color-base-100"] == "#00ff00"
      assert Regex.scan(~r/--color-base-100:/, css) == [["--color-base-100:"]]
    end

    test "normalises bare picker values before persistence", %{socket: socket} do
      socket = put_token!(socket, "color-base-100", "ffffff")

      assert custom_theme(socket)["color-base-100"] == "#ffffff"
    end

    test "rejects unsafe values without changing the palette", %{socket: socket} do
      socket = put_token!(socket, "color-secondary", "#123456")

      assert {:noreply, rejected_socket} =
               LiveHandler.handle_event(
                 "put_custom_theme_token",
                 %{
                   "token" => "color-primary",
                   "value" => "fff; --color-secondary: red",
                   "scope" => "user"
                 },
                 socket
               )

      assert custom_theme(rejected_socket) == %{"color-secondary" => "#123456"}
    end

    test "rejects unknown theme keys without changing the palette", %{socket: socket} do
      assert {:noreply, rejected_socket} =
               LiveHandler.handle_event(
                 "put_custom_theme_token",
                 %{
                   "token" => "not-a-theme-token",
                   "value" => "#123456",
                   "scope" => "user"
                 },
                 socket
               )

      assert custom_theme(rejected_socket) == %{}
    end

    test "validates and stores shape tokens through the same path", %{socket: socket} do
      socket = put_token!(socket, "radius-box", "0.5rem")

      assert custom_theme(socket)["radius-box"] == "0.5rem"
      assert DaisyTheme.style_attr_overrides(custom_theme(socket)) =~ "--radius-box: 0.5rem;"
    end
  end

  describe "reset_custom_theme_token" do
    test "resets the account token without removing the signed-in user's token" do
      account = fake_account!()
      user = fake_user!(account)
      socket = socket(user)
      socket = Phoenix.Component.assign(socket, :__context__, %{current_user: user, current_account: account})
      socket = put_token!(socket, "color-primary", "#111111")

      assert {:noreply, socket} =
               LiveHandler.handle_event("put_custom_theme_token",
                 %{"token" => "color-primary", "value" => "#222222", "scope" => "account"}, socket)

      assert {:noreply, socket} =
               LiveHandler.handle_event("reset_custom_theme_token",
                 %{"token" => "color-primary", "scope" => "account"}, socket)

      account = socket.assigns.__context__.current_account
      assert Settings.get([:ui, :theme, :custom], %{},
               current_account: account,
               one_scope_only: true
             )
             |> Enum.empty?()
      assert custom_theme(socket)["color-primary"] == "#111111"
    end

    test "removes only the selected colour", %{socket: socket} do
      socket = put_token!(socket, "color-primary", "#ff0000")
      socket = put_token!(socket, "color-secondary", "#0000ff")
      socket = reset_token!(socket, "color-primary")

      assert custom_theme(socket) == %{"color-secondary" => "#0000ff"}
    end

    test "removes historical atom and string representations deterministically", %{socket: socket} do
      assert {:ok, %{__context__: %{current_user: user}}} =
               Settings.put_raw(
                 [:ui, :theme, :custom],
                 %{
                   :"color-primary" => "#111111",
                   "color-primary" => "#222222",
                   "color-secondary" => "#333333"
                 },
                 current_user: socket.assigns.current_user
               )

      socket = user |> socket() |> reset_token!("color-primary")

      assert custom_theme(socket) == %{"color-secondary" => "#333333"}
    end

    test "ignores unknown keys without deleting valid colours", %{socket: socket} do
      socket = put_token!(socket, "color-primary", "#123456")
      socket = reset_token!(socket, "not-a-theme-token")

      assert custom_theme(socket) == %{"color-primary" => "#123456"}
    end

    test "removes a shape override without touching colours", %{socket: socket} do
      socket = put_token!(socket, "color-primary", "#123456")
      socket = put_token!(socket, "radius-box", "1rem")
      socket = reset_token!(socket, "radius-box")

      assert custom_theme(socket) == %{"color-primary" => "#123456"}
    end
  end

  describe "reset_custom_theme" do
    test "removes every override in the current scope", %{socket: socket} do
      socket = put_token!(socket, "color-primary", "#123456")
      socket = put_token!(socket, "color-secondary", "#abcdef")

      assert {:noreply, socket} =
               LiveHandler.handle_event(
                 "reset_custom_theme",
                 %{"scope" => "user"},
                 socket
               )

      assert custom_theme(socket) == %{}
    end
  end
end
