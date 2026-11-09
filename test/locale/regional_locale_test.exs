defmodule Bonfire.UI.Common.RegionalLocaleTest do
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui
  import Phoenix.LiveViewTest
  alias Bonfire.Common.Localise
  alias Bonfire.Common.Settings
  alias Cldr.Plug.SetLocale
  alias Plug.Conn
  alias Bonfire.UI.Common.LivePlugs.Locale

  # The Gettext locale is per process, so restore it after each test
  setup do
    on_exit(fn -> Localise.put_locale("en") end)
    :ok
  end

  defp gettext_locale, do: Gettext.get_locale(Bonfire.Common.Localise.Gettext)

  defp mount_locale_for(user) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, __context__: %{}, current_user: user}
    }

    Localise.put_locale("en")
    Locale.mount(%{}, %{}, socket)
    gettext_locale()
  end

  defp user_with_locale(locale) do
    account = fake_account!()
    user = fake_user!(account)

    {:ok, _} =
      Settings.put([Bonfire.Common.Localise.Cldr, :default_locale], locale, current_user: user)

    {account, Bonfire.Common.Repo.preload(user, :settings, force: true)}
  end

  defp accept_language_locale(header) do
    Localise.put_locale("en")

    # a real request to a controller page (a LiveView page would reset the locale in its on_mount), so the `set_locale` plug in the router pipeline is the one under test
    conn()
    |> Conn.put_req_header("accept-language", header)
    |> get("/guest/error/404")

    gettext_locale()
  end

  describe "preconditions" do
    test "the regional catalogue exists and differs from the base one" do
      known = Gettext.known_locales(Bonfire.Common.Localise.Gettext)
      assert "fr" in known
      assert "fr_FR" in known

      assert Gettext.dgettext(Bonfire.Common.Localise.Gettext, "bonfire_ui_social", "Filter") ==
               "Filter"

      Gettext.put_locale(Bonfire.Common.Localise.Gettext, "fr")

      assert Gettext.dgettext(Bonfire.Common.Localise.Gettext, "bonfire_ui_social", "Filter") ==
               "Filtrer"

      Gettext.put_locale(Bonfire.Common.Localise.Gettext, "fr_FR")

      assert Gettext.dgettext(Bonfire.Common.Localise.Gettext, "bonfire_ui_social", "Filter") ==
               "Filtre"
    end
  end

  describe "CLDR resolution (the seam both paths share)" do
    for input <- ["fr_FR", "fr-FR"] do
      test "#{input} resolves to the fr_FR Gettext locale through Localise" do
        assert Localise.requested_gettext_locale(unquote(input)) == "fr_FR"
      end

      test "put_locale(#{input}) sets the fr_FR Gettext locale and leaves the CLDR locale to ex_cldr" do
        Localise.put_locale(unquote(input))
        assert gettext_locale() == "fr_FR"
        assert to_string(Localise.get_locale().cldr_locale_name) == "fr"
      end
    end

    test "a validated tag resolves through its requested name" do
      {:ok, tag} = Bonfire.Common.Localise.Cldr.validate_locale("fr-FR")
      assert Localise.requested_gettext_locale(tag) == "fr_FR"
    end

    test "a locale without a catalogue of that exact name resolves to nil" do
      assert Localise.requested_gettext_locale("xx_YY") == nil
      assert Localise.requested_gettext_locale(nil) == nil
    end

    # The region of fr-FR is the likely territory of plain fr, so both supported entries match equally well and the order of the list decides
    test "fr-FR ties between fr and fr_FR, so the first entry in the list wins" do
      {:ok, tag} = Bonfire.Common.Localise.Cldr.validate_locale("fr-FR")
      opts = [backend: Bonfire.Common.Localise.Cldr]

      assert {:ok, "fr_FR", _} =
               Cldr.Locale.Match.best_match(tag, [supported: ["fr_FR", "fr"]] ++ opts)

      assert {:ok, "fr", _} =
               Cldr.Locale.Match.best_match(tag, [supported: ["fr", "fr_FR"]] ++ opts)
    end

    test "the best match still reports the language ex_cldr picked, while Gettext gets the region" do
      assert {:ok, best} = Localise.put_best_locale_match(["fr-FR", "en"])
      assert to_string(best) == "fr"
      assert gettext_locale() == "fr_FR"
    end
  end

  describe "settings path (LiveView on_mount)" do
    test "control: a user setting of fr gets the fr catalogue" do
      {_account, user} = user_with_locale("fr")
      assert mount_locale_for(user) == "fr"
    end

    test "a user setting of fr_FR gets the fr_FR catalogue" do
      {_account, user} = user_with_locale("fr_FR")
      assert mount_locale_for(user) == "fr_FR"
    end

    test "a user setting of fr-FR gets the fr_FR catalogue" do
      {_account, user} = user_with_locale("fr-FR")
      assert mount_locale_for(user) == "fr_FR"
    end

    test "the best-match function itself resolves fr_FR to the fr_FR catalogue" do
      assert {:ok, _} = Localise.put_best_locale_match(["fr_FR"])
      assert gettext_locale() == "fr_FR"
    end

    test "a user setting of fr_FR renders the page with the fr CLDR locale" do
      {account, user} = user_with_locale("fr_FR")
      conn = conn(user: user, account: account)
      {:ok, view, _html} = live(conn, "/dashboard")

      # the span shows the CLDR locale, which stays the language ex_cldr resolved; the Gettext catalogue is asserted by the on_mount tests above
      assert view |> element("span[data-role=locale]") |> render() =~ "fr"
    end
  end

  describe "Accept-Language path (Cldr.Plug.SetLocale)" do
    test "control: fr gets the fr catalogue" do
      assert accept_language_locale("fr") == "fr"
    end

    test "fr-FR gets the fr_FR catalogue" do
      assert accept_language_locale("fr-FR") == "fr_FR"
    end

    test "fr_FR gets the fr_FR catalogue" do
      assert accept_language_locale("fr_FR") == "fr_FR"
    end
  end
end
