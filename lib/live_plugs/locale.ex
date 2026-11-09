defmodule Bonfire.UI.Common.LivePlugs.Locale do
  use Bonfire.UI.Common.Web, :live_plug

  @behaviour Bonfire.UI.Common.LivePlugModule

  @local_session_key Cldr.Plug.SetLocale.session_key()

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(_params, session, socket) do
    current_user = current_user(socket)

    # a LiveView rendered from a controller does not see the conn's account, and its connected mount runs in a new process with only the session, so with no user and no account in the socket the account is read from the session
    loaded_account =
      if !current_user, do: current_account(socket) || account_from_session(session)

    # with no user chosen yet (eg. the user picker) the account's language is used
    # an account that set no language of its own gets the browser's, as `put_locale_for_account/2` does for a controller page
    current_account = if loaded_account && own_language?(loaded_account), do: loaded_account

    # whether someone has a login, so their session carries the browser's extras
    logged_in = current_user || loaded_account || session["current_account_id"]

    # Get locale from session/cookie (set by Cldr.Plug.SetLocale or our JS hook)

    # the browser's other languages. Someone with a login gets them from the session, where the `set_locale` plug wrote them, as LiveView does not see request headers. A guest has no session write, but their first render (all a guest page does) runs in the process of the request, where the plug kept them.
    browser_extras =
      if logged_in do
        session
        |> Map.get(Bonfire.Common.Localise.fallback_session_key(), [])
        |> List.wrap()
      else
        Bonfire.Common.Localise.browser_extras_from_process()
      end

    locales =
      preferred_locales(
        current_user || current_account,
        Bonfire.Common.Localise.default_locale(),
        browser_extras
      )

    locales =
      if session_locale = session["locale"] || session[@local_session_key] do
        # For guests, use session/cookie if provided
        [session_locale] ++ locales
      else
        locales
      end

    {:ok, assign_put_locale(locales, socket)}
  end

  @doc """
  For a controller page once the user is loaded (the `LoadCurrentUser` plug), or the account when the session has no user yet (the `LoadCurrentAccount` plug): sets the locale the way the on_mount does, from `preferred_locales/3`, with the browser's extras taken from the session where the `set_locale` plug wrote them.
  """
  def put_locale_for(%{} = user_or_account, session_extras) do
    user_or_account
    |> preferred_locales(Bonfire.Common.Localise.default_locale(), List.wrap(session_extras))
    |> Bonfire.Common.Localise.put_best_locale_match()
  end

  @doc """
  For a controller page whose session has an account but no user (eg. the user picker): the account's own language, its extras, the browser's and the instance's, as `put_locale_for/2`. An account that set no language of its own gets browser detection, as a guest does, rather than the instance default. Returns the conn.
  """
  def put_locale_for_account(conn, account) do
    if own_language?(account) do
      put_locale_for(
        account,
        Plug.Conn.get_session(conn, Bonfire.Common.Localise.fallback_session_key())
      )

      conn
    else
      detect_for_conn(conn)
    end
  end

  @doc """
  Detects the locale from the request's `Accept-Language` and stores the browser's other languages: for a request where no user or account is loaded to take it from (a guest, a forced logout, a failed load). Only a session with a login also gets the extras written to it, so a guest gets no session write and no cookie.
  """
  def detect_for_conn(conn) do
    conn = Cldr.Plug.SetLocale.call(conn, Bonfire.Common.Localise.set_locale_config())

    # use the regional Gettext catalogue the visitor asked for when one exists, as ex_cldr resolves eg. fr-FR to fr
    case conn.private[:cldr_locale] do
      %{} = tag -> Bonfire.Common.Localise.put_requested_gettext_locale(tag, tag)
      _ -> nil
    end

    # the visitor's other languages from `Accept-Language`, for strings the page language lacks: in this process for controller pages and the first render of a LiveView page
    conn = Bonfire.Common.Localise.put_fallback_extras_from_conn(conn)

    if Bonfire.UI.Common.session_logged_in?(conn) do
      Bonfire.Common.Localise.put_browser_extras_in_session(conn)
    else
      conn
    end
  end

  @doc """
  The languages to render in, in order of preference: a user's language and their "Other languages I understand", then the browser's other languages (`browser_extras`), then the instance's `extra_locales`. The first one that exists is the page language (see `Bonfire.Common.Localise.put_best_locale_match/3`) and `put_fallback_extras/1` uses the others for strings it has not translated, until English (nothing after it is reached).

  For a visitor with no user the instance's default language comes after the browser's languages, so an English default cannot end the list before them.
  """
  def preferred_locales(
        current_user_or_instance \\ nil,
        default_locale \\ Bonfire.Common.Localise.default_locale(),
        browser_extras \\ []
      )

  def preferred_locales(%{__struct__: Bonfire.Data.Identity.Account} = account, default, extras) do
    scoped_preferred_locales([current_account: account], default, extras)
  end

  def preferred_locales(%{} = current_user, default_locale, browser_extras) do
    scoped_preferred_locales([current_user: current_user], default_locale, browser_extras)
  end

  def preferred_locales(_, default_locale, browser_extras) do
    browser_extras ++
      [default_locale || Bonfire.Common.Localise.default_locale()] ++
      instance_extra_locales()
  end

  # a session with an account and no user (a session with a user gets their own language, which the LiveView's other plugs load)
  defp account_from_session(%{"current_account_id" => account_id} = session)
       when is_binary(account_id) do
    if !session["current_user_id"] do
      maybe_apply(Bonfire.Me.Accounts, :get_current, [account_id], fallback_return: nil)
    end
  end

  defp account_from_session(_), do: nil

  # whether the account itself set a language, not the instance's default that the merged settings fall back to
  defp own_language?(account) do
    !!Bonfire.Common.Settings.get([Bonfire.Common.Localise.Cldr, :default_locale], nil,
      current_account: account,
      one_scope_only: true
    )
  end

  # the language and the extras set in the settings of whoever `scope_opts` names (a user, or an account when no user is chosen), then the browser's and the instance's
  defp scoped_preferred_locales(scope_opts, default_locale, browser_extras) do
    [
      Bonfire.Common.Settings.get(
        [Bonfire.Common.Localise.Cldr, :default_locale],
        default_locale || Bonfire.Common.Localise.default_locale(),
        scope_opts
      )
    ] ++
      Bonfire.Common.Settings.get([Bonfire.Common.Localise, :extra_locales], [], scope_opts) ++
      browser_extras ++ instance_extra_locales()
  end

  defp instance_extra_locales do
    Bonfire.Common.Config.get([Bonfire.Common.Localise, :extra_locales], [])
  end

  def assign_put_locale(locale, socket)
      when not is_nil(locale) and
             (is_binary(locale) or is_atom(locale) or (is_list(locale) and locale != [])) do
    do_assign_put_locale(locale, socket)
  end

  def assign_put_locale(_other, socket) do
    # If given no locale, or any other unexpected value, use default
    preferred_locales()
    |> do_assign_put_locale(socket)
  end

  defp do_assign_put_locale(locales, socket)
       when is_list(locales) and locales != [] do
    # set available UI locale that best matches user's preferences
    with {:ok, best} <- Bonfire.Common.Localise.put_best_locale_match(locales) do
      assign_global(socket, locales: locales, locale: best)
    else
      _ ->
        warn(locales, "No valid locale match, setting none")
        socket
    end
  end

  defp do_assign_put_locale(locale, socket)
       when not is_nil(locale) and (is_binary(locale) or is_atom(locale)) do
    # set current UI locale
    Bonfire.Common.Localise.put_locale(locale)

    assign_global(socket, locale: locale)
  end

  defp do_assign_put_locale(locale, socket) do
    warn(locale, "No valid locale given, and invalid default locale, setting none")
    socket
  end
end
