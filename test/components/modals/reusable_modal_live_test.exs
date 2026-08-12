defmodule Bonfire.UI.Common.ReusableModalLiveTest do
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui

  alias Bonfire.UI.Common.ReusableModalLive
  alias Phoenix.LiveView.Socket

  test "Escape closes immediately while retaining contents until cleanup" do
    socket = %Socket{
      assigns: %{
        __changed__: %{},
        id: "test-modal",
        show: true,
        close_motion: :animated,
        close_token: nil
      }
    }

    assert {:noreply, closing_socket} =
             ReusableModalLive.handle_event("close-key", %{"key" => "Escape"}, socket)

    assert closing_socket.assigns.show == false
    assert closing_socket.assigns.close_motion == :instant
    assert is_reference(closing_socket.assigns.close_token)

    assert {:ok, reset_socket} =
             ReusableModalLive.update(
               %{reset_after_close: closing_socket.assigns.close_token},
               closing_socket
             )

    assert reset_socket.assigns.show == false
    assert reset_socket.assigns.close_motion == :animated
    assert reset_socket.assigns.close_token == nil
  end
end
