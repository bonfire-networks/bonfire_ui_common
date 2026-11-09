defmodule Bonfire.UI.Common.FallbackExtrasTest do
  @moduledoc """
  A string missing from the page language is looked up in the languages the visitor also reads: a logged-in user's "Other languages I understand", then the browser's `Accept-Language` extras, then the instance's.

  The fixture is "3 days ago" in `bonfire_ui_common`, translated in `it` only (not `fr`, `fr_FR` or `es`), and "Active", translated in both `it` and `es`.
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Localise
  alias Bonfire.Common.Settings
  alias Bonfire.UI.Common.LivePlugs.Locale
  alias Plug.Conn
  import Phoenix.LiveViewTest, only: [live: 2, element: 2, render_change: 2]

  @domain "bonfire_ui_common"
  @italian_only "3 days ago"
  @italian_only_it "3 giorni fa"
  @both "Active"
  @both_it "Attivo"
  @both_es "Activo"
  @header "fr-FR,fr;q=0.9,it;q=0.8"
  @cap_key [:bonfire_common, Bonfire.Common.Localise, :max_fallback_extras]

  setup do
    on_exit(fn -> Localise.put_locale("en") end)
    :ok
  end

  defp get_text(msgid), do: Gettext.dgettext(Bonfire.Common.Localise.Gettext, @domain, msgid)

  # a real request to a controller page (a LiveView page would reset the locale in its on_mount), so the `set_locale` plug in the router pipeline is the one under test
  defp request(header) do
    Localise.put_locale("en")

    conn()
    |> Conn.put_req_header("accept-language", header)
    |> get("/guest/error/404")
  end

  # the first thing a LiveView page does: read the locale from the user and the session
  defp mount_as(user, session) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, __context__: %{}, current_user: user}
    }

    Localise.put_locale("en")
    Locale.mount(%{}, session, socket)
  end

  defp session_of(conn), do: Conn.get_session(conn)

  defp user_with(locale, extras, account \\ fake_account!()) do
    user = fake_user!(account)

    {:ok, _} =
      Settings.put([Bonfire.Common.Localise.Cldr, :default_locale], locale, current_user: user)

    # reload between the two writes: the second one starts from the user it is given
    user = Bonfire.Common.Repo.preload(user, :settings, force: true)
    {:ok, _} = Settings.put([Bonfire.Common.Localise, :extra_locales], extras, current_user: user)
    Bonfire.Common.Repo.preload(user, :settings, force: true)
  end

  describe "browser Accept-Language, controller page" do
    test "the extras after the best match are used" do
      request(@header)
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
      assert get_text(@italian_only) == @italian_only_it
    end

    test "the chain stops at English" do
      request("fr-FR,en;q=0.9,it;q=0.8")
      assert get_text(@italian_only) == @italian_only
    end
  end

  defp session_cookies(conn) do
    conn
    |> Conn.get_resp_header("set-cookie")
    |> Enum.filter(&String.contains?(&1, "_bonfire_key"))
  end

  describe "guests stay cookieless" do
    test "control: a logged-in request with the same header does set the session cookie" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      conn = request_as(user, account, @header, "/account/password/change")
      assert session_cookies(conn) != []
    end

    for path <- ["/guest/error/404", "/about?test=guest_cookieless"] do
      test "a guest with extras in Accept-Language gets no session cookie on #{path}" do
        Localise.put_locale("en")

        conn =
          conn()
          |> Conn.put_req_header("accept-language", @header)
          |> get(unquote(path))

        assert session_cookies(conn) == []
        assert Conn.get_session(conn, Localise.fallback_session_key()) == nil
      end
    end

    test "a logged-in user whose extras are unchanged gets no session rewrite" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      first = request_as(user, account, @header, "/account/password/change")
      # proves the positive: the first request wrote the session
      assert session_cookies(first) != []

      second =
        first
        |> recycle()
        |> Conn.put_req_header("accept-language", @header)
        |> get("/account/password/change")

      assert session_cookies(second) == []
    end

    test "a logged-in user whose extras changed gets the session rewritten" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      first = request_as(user, account, @header, "/account/password/change")
      assert session_cookies(first) != []

      second =
        first
        |> recycle()
        |> Conn.put_req_header("accept-language", "fr-FR,fr;q=0.9,es;q=0.8")
        |> get("/account/password/change")

      assert session_cookies(second) != []
      assert Conn.get_session(second, Localise.fallback_session_key()) == ["fr-FR", "fr", "es"]
    end
  end

  describe "browser Accept-Language, LiveView page (guest first render, same process as the plug)" do
    test "an anonymous visitor gets the extras the plug kept in the process, with no session" do
      conn = request(@header)
      assert Conn.get_session(conn, Localise.fallback_session_key()) == nil
      mount_as(nil, %{})
      assert get_text(@italian_only) == @italian_only_it
    end

    test "English before the extra stops the chain" do
      "fr-FR,en;q=0.9,it;q=0.8" |> request()
      mount_as(nil, %{})
      assert get_text(@italian_only) == @italian_only
    end

    test "control: with no extras in the session the string stays English" do
      mount_as(nil, %{"cldr_locale" => "fr-FR"})
      assert get_text(@italian_only) == @italian_only
    end
  end

  # a real request as a logged-in user to a controller page: the account-required change-password form loads the user in its pipeline, and the `/guest/error` page is on `:browser_guest`, which never loads the user
  defp request_as(user, account, header, path) do
    Localise.put_locale("en")

    conn(user: user, account: account)
    |> Conn.put_req_header("accept-language", header)
    |> get(path)
  end

  describe "logged-in user, controller page that loads the user" do
    @page "/account/password/change"

    test "their own language wins over the browser's" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      request_as(user, account, "it", @page)
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end

    test "their own extras apply" do
      account = fake_account!()
      user = user_with("fr_FR", ["it"], account)
      request_as(user, account, "es", @page)
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
      assert get_text(@italian_only) == @italian_only_it
    end

    test "the browser's extras come after theirs" do
      account = fake_account!()
      user = user_with("fr_FR", ["es"], account)
      request_as(user, account, @header, @page)
      assert get_text(@both) == @both_es
      assert get_text(@italian_only) == @italian_only_it
    end

    test "the browser's extras still reach the session for LiveView pages" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      conn = request_as(user, account, @header, @page)
      assert Conn.get_session(conn, Localise.fallback_session_key()) == ["fr-FR", "fr", "it"]
    end

    test "a guest on a route that loads no user keeps browser detection" do
      request("it")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "it"
    end
  end

  describe "logged-in user, controller page that never loads the user" do
    test "the browser's language is detected, as before" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      request_as(user, account, "it", "/guest/error/404")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "it"
    end
  end

  # an account whose own settings hold the language and extras (`nil` language: none set)
  defp account_with(locale, extras) do
    account = fake_account!()

    account =
      if locale do
        {:ok, _} =
          Settings.put([Bonfire.Common.Localise.Cldr, :default_locale], locale,
            current_account: account
          )

        Bonfire.Common.Repo.preload(account, :settings, force: true)
      else
        account
      end

    {:ok, _} =
      Settings.put([Bonfire.Common.Localise, :extra_locales], extras, current_account: account)

    Bonfire.Common.Repo.preload(account, :settings, force: true)
  end

  # a session with an account and no user, as after login before a user is picked
  defp account_only_request(account, header, path \\ "/switch-user") do
    Localise.put_locale("en")

    conn(account: account)
    |> Conn.put_req_header("accept-language", header)
    |> get(path)
  end

  describe "account-only session (no user chosen yet)" do
    test "the account's language wins over the browser's" do
      account = account_with("fr_FR", [])
      account_only_request(account, "it")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end

    test "the account's extras apply, then the browser's" do
      account = account_with("fr_FR", ["es"])
      account_only_request(account, @header)
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
      assert get_text(@both) == @both_es
      assert get_text(@italian_only) == @italian_only_it
    end

    test "an account with no language set gets the browser's" do
      account = account_with(nil, [])
      account_only_request(account, "it")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "it"
    end

    test "a LiveView page uses the account's language" do
      account = account_with("fr_FR", ["it"])
      conn = account_only_request(account, "es")
      session = session_of(conn)
      {:ok, _} = mount_as_account(account, session)
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
      assert get_text(@italian_only) == @italian_only_it
    end

    test "a LiveView page of an account with no language gets the browser's" do
      account = account_with(nil, [])
      conn = account_only_request(account, @header)
      {:ok, _} = mount_as_account(account, session_of(conn))
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
      assert get_text(@italian_only) == @italian_only_it
    end

    test "a logged-in user's own language wins over their account's" do
      account = account_with("es", [])
      user = user_with("fr_FR", [], account)
      request_as(user, account, "it", "/account/password/change")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end
  end

  describe "no user and no account loaded" do
    test "a forced logout falls back to browser detection" do
      account = fake_account!()
      user = fake_user!(account)
      Bonfire.Common.Cache.put("force_logout:#{user.id}", true)
      request_as(user, account, "it", "/account/password/change")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "it"
    end

    test "a session whose user cannot be loaded falls back to browser detection" do
      Localise.put_locale("en")

      conn(user: Needle.UID.generate())
      |> Conn.put_req_header("accept-language", "it")
      |> get("/account/password/change")

      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "it"
    end
  end

  # the `lang` of the page's root element: the base language of the locale its LiveView rendered in (`fr` for `fr_FR`)
  defp page_lang(conn) do
    [_, lang] = Regex.run(~r/<html[^>]*\slang="([^"]*)"/, conn.resp_body)
    lang
  end

  # a LiveView rendered from a controller: its on_mount does not see the conn's user or account, so it has to keep the locale the plugs chose
  describe "LiveView rendered from a controller" do
    test "a user keeps their own language" do
      account = fake_account!()
      user = user_with("fr_FR", [], account)
      conn = request_as(user, account, "it", "/account/password/change")
      assert conn.status == 200
      assert page_lang(conn) == "fr"
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end

    test "an account-only session keeps the account's language" do
      account = account_with("fr_FR", [])
      conn = account_only_request(account, "it", "/account/password/change")
      assert conn.status == 200
      assert page_lang(conn) == "fr"
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end

    test "an account-only session with extras keeps the account's language and its extras" do
      account = account_with("fr_FR", ["it"])
      conn = account_only_request(account, "es", "/account/password/change")
      assert page_lang(conn) == "fr"
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
      assert get_text(@italian_only) == @italian_only_it
    end

    test "an account-only session with no language set gets the browser's" do
      account = account_with(nil, [])
      conn = account_only_request(account, "it", "/account/password/change")
      assert page_lang(conn) == "it"
    end

    test "the user picker, a controller-rendered LiveView of an account-only session" do
      account = account_with("fr_FR", [])
      fake_user!(account)
      conn = account_only_request(account, "it", "/switch-user")
      assert conn.status == 200
      assert page_lang(conn) == "fr"
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end

    test "a guest gets the browser's language" do
      Localise.put_locale("en")

      conn =
        conn()
        |> Conn.put_req_header("accept-language", "it")
        |> get("/login")

      assert conn.status == 200
      assert page_lang(conn) == "it"
    end

    test "the connected mount, a new process with only the session, uses the account's language" do
      account = account_with("fr_FR", ["it"])
      session = session_of(account_only_request(account, "es", "/account/password/change"))
      assert session["current_account_id"] == account.id

      Task.async(fn ->
        {:ok, _} = mount_as(nil, session)
        {Gettext.get_locale(Bonfire.Common.Localise.Gettext), get_text(@italian_only)}
      end)
      |> Task.await()
      |> then(fn {locale, text} ->
        assert locale == "fr_FR"
        assert text == @italian_only_it
      end)
    end

    test "the connected mount of an account with no language uses the browser's from the session" do
      account = account_with(nil, [])
      session = session_of(account_only_request(account, "it", "/account/password/change"))

      Task.async(fn ->
        {:ok, _} = mount_as(nil, session)
        Gettext.get_locale(Bonfire.Common.Localise.Gettext)
      end)
      |> Task.await()
      |> then(&assert(&1 == "it"))
    end
  end

  defp mount_as_account(account, session) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        __context__: %{current_account: account},
        current_account: account
      }
    }

    Localise.put_locale("en")
    Locale.mount(%{}, session, socket)
  end

  # the session a logged-in request leaves, which carries the browser's extras for their LiveView pages (a guest request leaves none)
  defp logged_in_session(extras) do
    account = fake_account!()
    user = user_with("fr_FR", extras, account)

    {user, request_as(user, account, @header, "/account/password/change") |> session_of()}
  end

  describe "logged-in user" do
    test "their own extras come before the browser's" do
      {user, session} = logged_in_session(["es"])
      mount_as(user, session)
      assert get_text(@both) == @both_es
    end

    test "the browser's extras come after theirs, for a string only the browser's language has" do
      {user, session} = logged_in_session(["es"])
      mount_as(user, session)
      assert get_text(@italian_only) == @italian_only_it
    end

    test "with no extras set they get the browser's" do
      {user, session} = logged_in_session([])
      mount_as(user, session)
      assert get_text(@both) == @both_it
    end

    test "their own extras work without a browser header" do
      user = user_with("fr_FR", ["it"])
      mount_as(user, %{})
      assert get_text(@italian_only) == @italian_only_it
    end

    test "the cap applies across the whole list" do
      Process.put(@cap_key, 1)
      {user, session} = logged_in_session(["es"])
      mount_as(user, session)
      # es has the domain but not the string, which uses up the single try
      assert get_text(@italian_only) == @italian_only
    end
  end

  # the language picker on the settings page, as a user uses it
  defp pick_language(user, account, locale) do
    {:ok, view, _html} =
      live(conn(user: user, account: account), "/settings/user/preferences/appearance")

    view
    |> element("form[data-scope=set_language]")
    |> render_change(%{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => locale}})
  end

  # what the account itself holds, read from its own scope alone and from a fresh load
  defp account_language(account) do
    Settings.get([Bonfire.Common.Localise.Cldr, :default_locale], nil,
      current_account: Bonfire.Me.Accounts.get_current(account.id),
      one_scope_only: true
    )
  end

  describe "a user's language fills their account's, if unset" do
    test "an account with no language gets the one a user picks" do
      account = fake_account!()
      user = fake_user!(account)
      assert account_language(account) == nil
      pick_language(user, account, "fr_FR")
      assert to_string(account_language(account)) == "fr_FR"
    end

    test "a later change by the user leaves the account's as it was" do
      account = fake_account!()
      user = fake_user!(account)
      pick_language(user, account, "fr_FR")
      pick_language(user, account, "it")
      assert to_string(account_language(account)) == "fr_FR"
    end

    test "an account that has a language keeps it" do
      account = account_with("es", [])
      user = fake_user!(account)
      pick_language(user, account, "fr_FR")
      assert to_string(account_language(account)) == "es"
    end

    test "an account-only session then renders in the user's language" do
      account = fake_account!()
      user = fake_user!(account)
      pick_language(user, account, "fr_FR")
      account_only_request(Bonfire.Me.Accounts.get_current(account.id), "it")
      assert Gettext.get_locale(Bonfire.Common.Localise.Gettext) == "fr_FR"
    end
  end
end
