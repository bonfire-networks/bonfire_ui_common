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
    
    locale = if current_user do
      # For logged-in users, use Settings.get which handles the full hierarchy:
      # 1. User settings (if set)
      # 2. Instance settings (if admin configured)  
      # 3. Config/default
      # We pass session_locale as default so cookie/session acts as final fallback
      Bonfire.Common.Settings.get(
        [Bonfire.Common.Localise.Cldr, :default_locale], 
        session_locale,
        current_user: current_user
      )
    else
      # For guests, use session/cookie locale or system default
      session_locale || Bonfire.Common.Localise.default_locale()
    end
    
    {:ok, assign_put_locale(locale, current_user, socket)}
  end

  def assign_put_locale(nil, _current_user, socket) do
    # When no locale is found, use the default
    Bonfire.Common.Localise.default_locale()
    |> assign_put_locale(socket)
  end

  def assign_put_locale(locale, _current_user, socket) when is_binary(locale) or is_atom(locale) do
    assign_put_locale(locale, socket)
  end
  
  def assign_put_locale(locale, socket) when is_binary(locale) or is_atom(locale) do
    # set current UI locale
    Bonfire.Common.Localise.put_locale(locale)

    assign_global(socket, locale: locale)
  end
  
  def assign_put_locale(_other, _current_user, socket) do
    # For any other unexpected value, use default
    Bonfire.Common.Localise.default_locale()
    |> assign_put_locale(socket)
  end

end
