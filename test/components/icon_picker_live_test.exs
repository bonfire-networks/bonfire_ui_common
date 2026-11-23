defmodule Bonfire.UI.Common.IconPickerLiveTest do
  use ExUnit.Case, async: true
  use Surface.LiveViewTest

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  alias Bonfire.UI.Common.IconPickerLive
  alias Bonfire.UI.Common.SwatchPickerLive

  defp compiled_css, do: File.read!(Path.join(Iconify.static_path(), "icons.css"))

  test "the offered icons are the 35 of the event categories, 42 more and 35 by theme, with none twice" do
    icons = IconPickerLive.curated_icons()

    assert length(icons) == 112
    assert icons == Enum.uniq(icons)
    assert Enum.all?(icons, &String.starts_with?(&1, "ph:"))
  end

  test "the offered icons are the three configured lists, in order" do
    config = Application.fetch_env!(:bonfire_ui_common, IconPickerLive)

    assert IconPickerLive.curated_icons() ==
             config[:category_icons] ++ config[:more_icons] ++ config[:themed_icons]
  end

  test "every offered icon is in the compiled set, so it is drawn" do
    css = compiled_css()

    missing =
      for icon <- IconPickerLive.curated_icons(),
          not String.contains?(css, ~s([iconify="#{icon}"])),
          do: icon

    assert missing == []
  end

  test "an icon is offered if it is curated or compiled, and nothing else is" do
    assert IconPickerLive.offered?("ph:music-notes-fill")
    refute IconPickerLive.offered?("ph:no-such-icon-fill")
    refute IconPickerLive.offered?("<script>")
    refute IconPickerLive.offered?(nil)
  end

  test "icons are named for reading" do
    assert IconPickerLive.readable("ph:music-notes-fill") == "music notes"
    assert IconPickerLive.readable("heroicons:user") == "user"
  end

  test "a given list is what is shown, and with none a search finds from the compiled set" do
    assert IconPickerLive.shown(["ph:a-fill"], "anything") == ["ph:a-fill"]
    # nothing until there is something to search
    assert IconPickerLive.shown(nil, "") == []
    assert IconPickerLive.shown(nil, "m") == []

    found = IconPickerLive.shown(nil, "music-notes")
    assert "ph:music-notes-fill" in found
    assert length(found) <= 60
  end

  test "the swatch picker shows every swatch, marks the selected one, and resets only when one is selected" do
    assigns = %{}

    html =
      render_surface do
        ~F"""
        <SwatchPickerLive selected="violet" object_id="x1" event="pick" reset_event="reset" />
        """
      end

    assert html =~ ~s(data-swatch="violet")
    assert html =~ ~s(data-swatch="rose")

    assert html =~
             ~r/data-swatch="violet"[^>]*aria-pressed="true"|aria-pressed="true"[^>]*data-swatch="violet"/

    assert html =~ "reset_colour"

    html =
      render_surface do
        ~F"""
        <SwatchPickerLive object_id="x1" event="pick" reset_event="reset" />
        """
      end

    refute html =~ "reset_colour"
    refute html =~ ~s(aria-pressed="true")
  end
end
