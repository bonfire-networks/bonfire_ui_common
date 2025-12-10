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

    # Get locale from session/cookie (set by Cldr.Plug.SetLocale or our JS hook)
    session_locale = session["locale"] || session[@local_session_key]

    locale =
      if current_user do
        # For logged-in users, use Settings.get which handles the full hierarchy:
        # 1a. User settings (if set)
        # 1b. Account settings (if set)
        # 2. Instance settings (if admin configured)  
        # 3. Config/default
        # We pass session_locale as default so cookie/session acts as final fallback
        [
          Bonfire.Common.Settings.get(
            [Bonfire.Common.Localise.Cldr, :default_locale],
            session_locale,
            current_user: current_user
          )
        ] ++
          Bonfire.Common.Settings.get(
            [Bonfire.Common.Localise, :extra_locales],
            [],
            current_user: current_user
          )
      else
        # For guests, use session/cookie if provided
        session_locale
      end

    {:ok, assign_put_locale(locale, socket)}
  end

  def assign_put_locale(locale, socket)
      when not is_nil(locale) and
             (is_binary(locale) or is_atom(locale) or (is_list(locale) and locale != [])) do
    do_assign_put_locale(locale, socket)
  end

  def assign_put_locale(_other, socket) do
    # If given no locale, or any other unexpected value, use default
    ([Bonfire.Common.Localise.default_locale()] ++
       Bonfire.Common.Config.get(
         [Bonfire.Common.Localise, :extra_locales],
         []
       ))
    |> do_assign_put_locale(socket)
  end

  defp do_assign_put_locale(locale, socket)
       when is_list(locale) and locale != [] do
    # set available UI locale that best matches user's preferences
    with {:ok, best} <- Bonfire.Common.Localise.put_best_locale_match(locale) do
      assign_global(socket, locale: best)
    else
      _ ->
        warn(locale, "No valid locale match, setting none")
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
