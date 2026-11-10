defmodule Bonfire.UI.Common.LocalePickerShareTest do
  @moduledoc """
  The language pickers (`ChangeLocaleLive` for the user's language, `ExtraLocalesLive` for the other languages they understand) show how much of each language is translated, from a fixture `coverage.json`.

  The test environment lists `en`, `es`, `fr`, `fr-FR` and `it`. The fixture has `fr` at 31%, `es` at 6%, `fr_FR` at 95%, and no entry for `it`. A second fixture has `fr_FR` at 100%.
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Localise

  @path Path.expand("../support/localisation/coverage.json", __DIR__)
  @full_path Path.expand("../support/localisation/coverage_full.json", __DIR__)

  # Elixir refuses these bidi characters written as-is in source
  @first_strong_isolate <<0x2068::utf8>>
  @pop_directional_isolate <<0x2069::utf8>>

  setup do
    # per process, so it can't leak into other tests the way a global `Config.put` would
    Process.put([:bonfire_common, Localise, :coverage_path], @path)
    :ok
  end

  defp user_picker do
    render_component(&Bonfire.UI.Common.ChangeLocaleLive.render/1, %{
      locale: "en",
      scope: nil,
      live_handler: "Bonfire.Common.Settings.LiveHandler",
      __context__: %{}
    })
    |> Floki.parse_document!()
  end

  defp add_picker do
    render_component(Bonfire.UI.Common.ExtraLocalesLive, %{
      id: "extra_locales_test",
      extra_locales: [],
      primary_locale: "en",
      scope: nil,
      __context__: %{}
    })
    |> Floki.parse_document!()
  end

  defp option(doc, selector, value) do
    doc |> Floki.find("#{selector} option[value='#{value}']") |> List.first()
  end

  defp option_text(doc, selector, value) do
    case option(doc, selector, value) do
      nil -> nil
      opt -> opt |> Floki.text() |> String.replace(~r/\s+/, " ") |> String.trim()
    end
  end

  @user "#change_locale"
  @add "select[name=new_locale]"

  test "control: the fixture locales are in both pickers" do
    for locale <- ["en", "es", "fr", "fr-FR", "it"] do
      assert option(user_picker(), @user, locale),
             "#{locale} should be listed in the user's language picker"
    end

    # the add-a-language picker leaves out the user's own language
    for locale <- ["es", "fr", "fr-FR", "it"] do
      assert option(add_picker(), @add, locale),
             "#{locale} should be listed in the add-a-language picker"
    end
  end

  test "the user's language picker shows a partly translated locale's share, rounded to the nearest 10" do
    assert option_text(user_picker(), @user, "fr") =~ "30% translated"
  end

  test "the user's language picker shows <10% for a barely translated locale" do
    assert option_text(user_picker(), @user, "es") =~ "<10% translated"
  end

  test "the user's language picker shows 'not translated yet' for a locale missing from the file, and keeps it listed" do
    assert option_text(user_picker(), @user, "it") =~ "not translated yet"
  end

  # Afrikaans is compiled for dates and numbers in the test environment but has no translation catalogue
  test "a language with no catalogue is listed in both pickers, as not translated yet" do
    # prove the positive first: a language with a catalogue and no entry in the file is listed the same way
    assert option_text(user_picker(), @user, "it") =~ "not translated yet"

    assert option_text(user_picker(), @user, "af") =~ "not translated yet"
    assert option_text(add_picker(), @add, "af") =~ "not translated yet"
  end

  test "the user's language picker shows nothing for English" do
    doc = user_picker()

    # prove the positive first: the same picker does show a share for fr
    assert option_text(doc, @user, "fr") =~ "translated"

    assert option(doc, @user, "en")
    refute option_text(doc, @user, "en") =~ "translated"
  end

  test "a locale at 90% or more but not complete is never shown as 100%" do
    doc = user_picker()

    assert option_text(doc, @user, "fr-FR") =~ "90% translated"
    refute option_text(doc, @user, "fr-FR") =~ "100%"
  end

  test "a fully translated locale says so, in both pickers" do
    Process.put([:bonfire_common, Localise, :coverage_path], @full_path)

    assert option_text(user_picker(), @user, "fr-FR") =~ "fully translated"
    assert option_text(add_picker(), @add, "fr-FR") =~ "fully translated"
    refute option_text(user_picker(), @user, "fr-FR") =~ "100%"
  end

  test "the add-a-language picker shows the same shares" do
    doc = add_picker()

    assert option_text(doc, @add, "fr") =~ "30% translated"
    assert option_text(doc, @add, "es") =~ "<10% translated"
    assert option_text(doc, @add, "it") =~ "not translated yet"
    assert option_text(doc, @add, "fr-FR") =~ "90% translated"
  end

  # an option can only hold text (no `<bdi>`), and its direction comes from its first strong letter, so a right-to-left name such as "العربية" would turn "<10% translated" into "translated %10>"
  test "the language name is isolated in both pickers, so a right-to-left name doesn't reorder the share after it" do
    isolated =
      @first_strong_isolate <> "français" <> @pop_directional_isolate <> " · 30% translated"

    assert option_text(user_picker(), @user, "fr") =~ isolated
    assert option_text(add_picker(), @add, "fr") =~ isolated
  end
end
