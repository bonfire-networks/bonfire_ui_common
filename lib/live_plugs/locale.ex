defmodule Bonfire.UI.Common.LivePlugs.Locale do
  use Bonfire.UI.Common.Web, :live_plug

  @behaviour Bonfire.UI.Common.LivePlugModule

  @local_session_key Cldr.Plug.SetLocale.session_key()

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  # `locale` in session as override
  def mount(_, %{"locale" => locale}, socket),
    do: {:ok, assign_put_locale(locale, current_user(socket), socket)}

  # local derived from browser, cookies, etc, by Cldr.Plug.SetLocale
  def mount(_, %{@local_session_key => locale}, socket),
    do: {:ok, assign_put_locale(locale, current_user(socket), socket)}

  # from settings or default
  def mount(_, _, socket), do: {:ok, assign_put_locale(nil, current_user(socket), socket)}

  def assign_put_locale(locale, current_user, socket)
      when is_nil(locale) or current_user != nil do
    # TODO: from Settings
    maybe_apply(
      Bonfire.Common.Settings,
      :get,
      [[Bonfire.Common.Localise.Cldr, :default_locale], nil, socket],
      &default/2
    )
    |> assign_put_locale(socket)
  end

  def assign_put_locale(locale, socket) do
    # set current UI locale
    Bonfire.Common.Localise.put_locale(locale)

    assign_global(socket, locale: locale)
  end

  def default(_, _) do
    debug("No locale detected, or specified in session, so use default")
    Bonfire.Common.Localise.default_locale()
  end
end
