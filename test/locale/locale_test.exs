defmodule Bonfire.UI.Common.LocaleTest do
  use Bonfire.UI.Common.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  # alias Bonfire.Social.Fake
  import Phoenix.LiveViewTest
  alias Bonfire.Common.Localise
  alias Cldr.Plug.SetLocale
  alias Plug.Conn
  alias Bonfire.UI.Common.LivePlugs.Locale

  test "locale is detected from accept header" do
    conn =
      conn()
      |> Conn.put_req_header(
        "accept-language",
        "es_MX, es, en-gb;q=0.8, en;q=0.7"
      )
      |> Plug.Test.init_test_session(%{})
      |> Conn.fetch_query_params()
      |> Conn.fetch_session()
      |> SetLocale.call(Localise.set_locale_config())

    # Read the locale from the connection's private data
    detected_locale = conn.private[:cldr_locale]
    assert "es-MX" == detected_locale.canonical_locale_name
  end

  test "valid locale is detected" do
    conn =
      conn()
      |> Conn.put_req_header("accept-language", "xyz, es;q=0.8")
      |> Plug.Test.init_test_session(%{})
      |> Conn.fetch_query_params()
      |> Conn.fetch_session()
      |> SetLocale.call(Localise.set_locale_config())

    # Read the locale from the connection's private data
    detected_locale = conn.private[:cldr_locale]
    assert "es" == detected_locale.canonical_locale_name
  end

  # Test that when no locale information is provided, it falls back to the default
  # This test fails because Cldr.Plug.SetLocale seems to pass the default locale as a string ("en")
  test "locale falls back to default when no locale is provided" do
    # Create a basic connection with no locale information
    conn()
    |> Plug.Test.init_test_session(%{})
    |> Conn.fetch_query_params()
    |> Conn.fetch_session()
    # Call the SetLocale plug with the application's config
    |> SetLocale.call(Localise.set_locale_config())

    # Assert that the locale was set to the default ("en")
    assert "en" == Localise.get_locale().canonical_locale_name
  end

  test "locale in query string takes precedence" do
    # Use Plug.Test.conn to simulate a request with query params
    conn = Plug.Test.conn(:get, "/?locale=es")
    # Add headers and ensure session is initialized (ConnCase might do this, but being explicit)
    conn =
      conn
      |> Plug.Conn.put_req_header("accept-language", "fr")
      |> Plug.Test.init_test_session(%{})

    # Fetch params and session *before* calling the plug
    conn =
      conn
      |> Conn.fetch_query_params()
      |> Conn.fetch_session()

    # Call the SetLocale plug
    conn = SetLocale.call(conn, Localise.set_locale_config())

    # Read the locale from the connection's private data
    detected_locale = conn.private[:cldr_locale]
    assert "es" == detected_locale.canonical_locale_name
  end

  describe "assign_put_locale/2" do
    test "selects best match from user preferences" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      preferred = ["fr-CA", "es", "en"]
      # Use actual supported locales
      # supported = Bonfire.Common.Localise.localisation_locales()
      # Should select the best match from supported locales
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(preferred, socket)
      # assert socket.assigns.locale in supported
      assert socket.assigns.locale == :fr
    end

    test "assign_put_locale sets locale from string" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale("es", socket)
      assert socket.assigns.locale == "es"
    end

    test "assign_put_locale falls back to default on nil" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(nil, socket)
      assert to_string(socket.assigns.locale) == Bonfire.Common.Localise.default_locale()
    end

    test "assign_put_locale falls back to default if all preferred are unsupported" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      preferred = ["xx", "yy", "zz"]
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(preferred, socket)
      assert to_string(socket.assigns.locale) == Bonfire.Common.Localise.default_locale()
    end

    test "assign_put_locale falls back to default if preferred list is empty" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      preferred = []
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(preferred, socket)
      assert to_string(socket.assigns.locale) == Bonfire.Common.Localise.default_locale()
    end

    test "assign_put_locale ignores duplicates and selects best match" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      preferred = ["fr", "fr", "en"]
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(preferred, socket)
      assert socket.assigns.locale == :fr
    end

    test "assign_put_locale handles atom and string forms" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      preferred = [:fr, "en"]
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(preferred, socket)
      assert socket.assigns.locale in [:fr, :en]
    end

    test "assign_put_locale ignores nil and invalid values" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      preferred = [nil, "en", "zz"]
      socket = Bonfire.UI.Common.LivePlugs.Locale.assign_put_locale(preferred, socket)
      assert socket.assigns.locale == :en
    end
  end

  describe "put_locale/1 sets correct Gettext locale (POSIX format)" do
    test "regional locale with hyphen gets converted to underscore for Gettext" do
      Localise.put_locale("fr-CA")
      gettext_locale = Gettext.get_locale()
      # Gettext locale must use underscores, not hyphens
      assert gettext_locale =~ "fr"

      refute String.contains?(gettext_locale, "-"),
             "Gettext locale #{inspect(gettext_locale)} should not contain hyphens"
    end

    test "regional locale with underscore is passed through correctly" do
      Localise.put_locale("fr_CA")
      gettext_locale = Gettext.get_locale()
      # Gettext locale must use underscores, not hyphens
      assert gettext_locale =~ "fr"

      refute String.contains?(gettext_locale, "-"),
             "Gettext locale #{inspect(gettext_locale)} should not contain hyphens"
    end

    test "simple locale without region is unaffected" do
      Localise.put_locale("en")
      assert Gettext.get_locale() == "en"
    end
  end

  describe "put_best_locale_match/1 sets correct Gettext locale" do
    test "BCP47 regional locale resolves to POSIX Gettext locale" do
      {:ok, _best} = Localise.put_best_locale_match(["fr-CA"])
      gettext_locale = Gettext.get_locale()
      # Gettext locale must use underscores, not hyphens
      assert gettext_locale =~ "fr"

      refute String.contains?(gettext_locale, "-"),
             "Gettext locale #{inspect(gettext_locale)} should not contain hyphens"
    end
  end
end
