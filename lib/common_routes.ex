defmodule Bonfire.UI.Common.Routes do
  alias Bonfire.Common.Config

  defmacro __using__(_) do
    quote do
      pipeline :basic do
        plug(:fetch_session)
        plug(:put_root_layout, {Bonfire.UI.Common.LayoutView, :root})
        plug(RemoteIp)
      end

      pipeline :basic_html do
        plug(:basic)
        plug(:accepts, ["html"])
      end

      pipeline :browser do
        plug(:basic)
        plug(:accepts, ["html", "activity+json", "json", "ld+json"])

        plug(PhoenixGon.Pipeline,
          # FIXME: this doesn't take into account runtime config
          assets: &Bonfire.UI.Common.Routes.gon_js_config/0
        )

        plug(Cldr.Plug.SetLocale, Bonfire.Common.Localise.set_locale_config())

        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)

        # detect Accept headers to serve JSON or HTML
        plug(Bonfire.UI.Common.Plugs.ActivityPub)

        # plug(:load_current_auth) # do we need this here?

        # plug(Bonfire.UI.Common.MaybeStaticGeneratorPlug)

        plug(:fetch_live_flash)

        # plug Bonfire.UI.Me.Plugs.Locale # TODO: skip guessing a locale if the user has one in preferences
      end

      pipeline :throttle_plug_attacks do
        plug(:basic)
        plug Bonfire.UI.Common.PlugProtect
      end

      pipeline :static do
        plug(:basic_html)
        plug(Bonfire.UI.Common.StaticGeneratorPlug)
      end

      scope "/#{Bonfire.UI.Common.StaticGenerator.base_path()}" do
        pipe_through(:static)

        match(
          :*,
          "/*path",
          Bonfire.UI.Common.StaticFallbackController,
          :fallback
        )
      end

      # pages anyone can view
      scope "/" do
        pipe_through(:browser)

        get("/guest/error", Bonfire.UI.Common.ErrorController, as: :error_guest)
        get("/guest/error/:code", Bonfire.UI.Common.ErrorController, as: :error_guest)

        post(
          "/LiveHandler/:live_handler",
          Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller,
          :fallback
        )

        get(
          "/LiveHandler/:live_handler",
          Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller,
          :fallback
        )

        post(
          "/LiveHandler/:live_handler/:action",
          Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller,
          :fallback
        )

        get(
          "/LiveHandler/:live_handler/:action",
          Bonfire.UI.Common.LiveHandlers.GracefulDegradation.Controller,
          :fallback
        )

        post(
          "/session_redirect",
          Bonfire.UI.Common.SessionRedirectController,
          :set_and_redirect
        )
      end

      # pages only guests can view
      scope "/", Bonfire do
        pipe_through(:browser)
        pipe_through(:guest_only)
      end

      # pages you need an account to view
      scope "/", Bonfire do
        pipe_through(:browser)
        pipe_through(:account_required)
      end

      # pages you need to view as a user
      scope "/", Bonfire do
        pipe_through(:browser)
        pipe_through(:user_required)
      end

      # pages only admins can view
      scope "/settings/admin" do
        pipe_through(:browser)
        pipe_through(:admin_required)
      end
    end
  end

  @doc "Config keys to make available in JS (via Phoenix Gon lib)"
  def gon_js_config() do
    Config.get(:js_config, %{})
    |> Enum.into(
      %{
        # random_socket_id: Bonfire.Common.Text.random_string(4)
      }
    )
  end
end
