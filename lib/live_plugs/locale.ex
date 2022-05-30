defmodule Bonfire.UI.Common.LivePlugs.Locale do
  use Bonfire.UI.Common

  @local_session_key Cldr.Plug.SetLocale.session_key()

  def mount(_, %{"locale" => locale}, socket), do: {:ok, assign_put_locale(locale, socket)} # `locale` in session as override
  def mount(_, %{@local_session_key => locale}, socket), do: {:ok, assign_put_locale(locale, socket)} # local derived from browser, cookies, etc, by Cldr.Plug.SetLocale
  def mount(_, _, socket), do: {:ok, assign_put_locale(nil, socket)} # from settings or default


  def assign_put_locale(nil, socket) do
    # TODO: from Settings
    maybe_apply(Bonfire.Me.Settings, :get, [[Bonfire.Common.Localise.Cldr, :default_locale], nil, socket], &default/2)
    |> assign_put_locale(socket)
  end

  def assign_put_locale(locale, socket) do
    Bonfire.Common.Localise.put_locale(locale) # set current UI locale

    assign_global(socket, locale: locale)
  end

  def default(_, _) do
    debug("No locale detected, or specified in session, so use default")
    Bonfire.Common.Localise.default_locale()
  end

end
