defmodule Bonfire.UI.Common.ReusableModalLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui

  alias Bonfire.UI.Common.ReusableModalLive
  alias Phoenix.LiveView.Socket

  test "close control stays above modal content with an accessible hit target" do
    html =
      render_component(ReusableModalLive,
        id: "test-modal",
        show: true,
        title_text: "Test modal",
        no_header: true,
        no_actions: true
      )

    document = Floki.parse_fragment!(html)
    [close_button] = Floki.find(document, "button[data-role=close-modal]")

    assert Floki.attribute(close_button, "aria-label") == ["Close modal"]
    assert Floki.attribute(close_button, "phx-click") == ["close"]
    assert Floki.attribute(close_button, "phx-target") == ["[id='test-modal']"]
    assert Enum.any?(Floki.attribute(close_button, "class"), &String.contains?(&1, "size-11"))
    assert Floki.find(document, "div.z-tooltip button[data-role=close-modal]") != []
    assert Floki.find(document, "[data-id=modal-contents].z-popover") != []
  end

  test "close click starts the animated close lifecycle" do
    socket = %Socket{
      assigns: %{
        __changed__: %{},
        id: "test-modal",
        show: true,
        close_motion: :animated,
        close_token: nil
      }
    }

    assert {:noreply, closing_socket} = ReusableModalLive.handle_event("close", %{}, socket)

    assert closing_socket.assigns.show == false
    assert closing_socket.assigns.close_motion == :animated
    assert is_reference(closing_socket.assigns.close_token)
  end

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
