defmodule Bonfire.UI.Common.UntrustedTextRenderTest do
  @moduledoc """
  Text that is not known to be sanitised markup (a page title made from a name, a flash message that may quote user input) is never output as raw HTML.
  """
  use ExUnit.Case, async: true
  use Surface.LiveViewTest

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  import Phoenix.LiveViewTest
  import Bonfire.UI.Common, only: [rich_untrusted: 1]

  alias Bonfire.UI.Common.PageHeaderLive
  alias Bonfire.UI.Common.NotificationLive

  @payload "<img src=x onerror=alert(1)>"

  defp live_onerror?(html), do: html =~ ~r/<img[^>]*onerror/i

  defp render_header(assigns),
    do:
      render_component(
        &PageHeaderLive.render/1,
        Map.merge(
          %{page_title: "Discussion", show_right_actions: false, __context__: %{}},
          Map.new(assigns)
        )
      )

  describe "page header title" do
    test "a hostile title renders without a live onerror" do
      refute live_onerror?(render_header(page_title: @payload))

      refute live_onerror?(
               render_header(
                 page_title: @payload,
                 page_title_context: %{name: "Place", path: "/p"}
               )
             )
    end

    test "a plain title is shown (control)" do
      assert render_header(page_title: "A plain title") =~ "A plain title"
    end
  end

  describe "flash messages" do
    defp render_flash(kind, message) do
      assigns = %{flash: %{kind => message}}

      render_surface do
        ~F"""
        <NotificationLive id="untrusted-flash" root_flash={@flash} />
        """
      end
    end

    for kind <- ["info", "error"] do
      test "a hostile #{kind} flash renders without a live onerror" do
        refute live_onerror?(render_flash(unquote(kind), @payload))
      end

      test "a plain #{kind} flash is shown (control)" do
        assert render_flash(unquote(kind), "All saved") =~ "All saved"
      end
    end
  end

  describe "rich_untrusted/1" do
    test "strips hostile markup (control)" do
      refute live_onerror?(@payload |> rich_untrusted() |> Phoenix.HTML.safe_to_string())
    end

    test "escapes instead of passing the markup raw when no sanitiser is available" do
      Process.put({:modularity_cache, Bonfire.Common.Text.SanitizeHTML}, :disabled)

      html = @payload |> rich_untrusted() |> Phoenix.HTML.safe_to_string()

      refute live_onerror?(html)
      assert html =~ "&lt;img"
    end
  end
end
