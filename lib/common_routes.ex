defmodule Bonfire.UI.Common.Routes do
  use Bonfire.Common.Config
  use Bonfire.Common.Localise
  require Bonfire.UI.Common.Web
  import Untangle

  # list all resources that will be needed later when rendering page, see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/103
  def early_hints_shared(),
    do:
      Bonfire.Common.Config.get(
        [Bonfire.UI.Common.Routes, :early_hints, :common],
        [
          "/css/app.css": [rel: "preload", as: "style"],
          "/images/icons/icons.css": [rel: "preload", as: "style"],
          "/images/icons/svg-inject.min.js": [rel: "preload", as: "script"]
        ],
        name: l("Early hints"),
        description: l("Common assets to send as early hints")
      )

  def early_hints_guest(),
    do:
      Bonfire.Common.Config.get(
        [Bonfire.UI.Common.Routes, :early_hints, :guest],
        [
          # here are resources needed by non-logged-in visitors
          # TODO: how can we avoid also including it for authed users?
          "/assets/bonfire_basic.js": [rel: "preload", as: "script"]
        ],
        name: l("Early hints"),
        description: l("Assets to send as early hints for guests (non logged in visitors)")
      ) ++ early_hints_shared()

  def early_hints_authed(),
    do:
      Bonfire.Common.Config.get(
        [Bonfire.UI.Common.Routes, :early_hints, :users],
        [
          # here are resources needed by logged-in visitors
          "/assets/bonfire_live.js": [rel: "preload", as: "script"]
        ],
        name: l("Early hints"),
        description: l("Assets to send as early hints for users (when logged in)")
      )

  # ++ early_hints_shared()

  defmacro __using__(_) do
    quote do
      def set_locale(conn, _opts) do
        try do
          Cldr.Plug.SetLocale.call(conn, Bonfire.Common.Localise.set_locale_config())
        rescue
          e ->
            error(e, "Locale setting failed")

            %{conn | private: Map.put(conn.private, :cldr_locale, "en")}
        end
      end

      @doc """
      Rate limit plug for controllers.

      Reads configuration from `Application.get_env(:bonfire, :rate_limit)[key_prefix]` 
      with fallback to default options provided in the plug call.

      ## Options

        * `:key_prefix` - Atom prefix for the rate limit bucket key (required)
        * `:scale_ms` - Default time window in milliseconds (can be overridden by config)
        * `:limit` - Default number of requests (can be overridden by config)
        * `:method` - Optional HTTP method to rate limit (e.g., "POST"). If provided, only requests
                      with this method will be rate limited. All other methods pass through.

      ## Examples

          # Rate limit all requests
          plug :rate_limit, 
            key_prefix: :api,
            scale_ms: 60_000,
            limit: 100
          
          # Rate limit only POST requests (form submissions)
          plug :rate_limit, 
            key_prefix: :forms,
            scale_ms: 60_000,
            limit: 5,
            method: "POST"
      """
      def rate_limit(conn, opts) do
        # Check if we should filter by HTTP method
        case Keyword.get(opts, :method) do
          nil ->
            # No method filter, rate limit all requests
            do_rate_limit(conn, opts)

          method when is_binary(method) ->
            # Only rate limit if method matches
            if conn.method == method do
              do_rate_limit(conn, opts)
            else
              conn
            end
        end
      end

      defp do_rate_limit(conn, opts) do
        key_prefix = Keyword.fetch!(opts, :key_prefix)

        # Read from config, falling back to defaults
        rate_config = Config.get([:bonfire, :rate_limit, key_prefix], [])
        scale_ms = Keyword.get(rate_config, :scale_ms) || Keyword.fetch!(opts, :scale_ms)
        limit = Keyword.get(rate_config, :limit) || Keyword.fetch!(opts, :limit)

        # Build rate limit key from IP
        ip = conn.remote_ip |> :inet.ntoa() |> to_string()
        key = "#{key_prefix}:#{ip}"

        case Bonfire.UI.Common.RateLimit.hit(key, scale_ms, limit) do
          {:allow, _count} ->
            conn

          {:deny, retry_after} ->
            Bonfire.UI.Common.Web.rate_limit_reached(conn, retry_after, opts)
        end
      end

      # Reads the session cookie (but does not write one unless the session is
      # modified). Used as the base for all browser and cacheable pipelines.
      pipeline :basic do
        plug(:fetch_session)
      end

      # Minimal pipeline for non-browser HTML routes that need a session.
      pipeline :basic_html do
        plug(:basic)
        plug(:accepts, ["html"])
      end

      # Minimal pipeline for JSON/ActivityPub routes that need a session.
      pipeline :basic_json do
        plug(:basic)
        plug(:accepts, ["activity+json", "json", "ld+json"])
      end

      # Content-type negotiation + HTTP/2 early hints for preloading assets.
      # Shared by :browser, :cacheable, and other pipelines that serve HTML.
      pipeline :browser_accepts do
        plug(:accepts, [
          "html",
          "activity+json",
          "json",
          "ld+json",
          "text",
          "markdown",
          "mjml",
          "xml",
          "atom+xml",
          "rss+xml",
          "swiftui",
          "jetpack"
        ])

        plug PlugEarlyHints, paths: Bonfire.UI.Common.Routes.early_hints_guest()
      end

      # CSRF protection + secure response headers (X-Frame-Options, CSP, etc.).
      # Must NOT be included in :cacheable pipelines — protect_from_forgery
      # writes a CSRF cookie that would be served to other users from CDN cache.
      pipeline :browser_security do
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
      end

      # Locale detection, root layout, Gon JS config, and content-type
      # redirect detection. Safe to include in cacheable pipelines — does not
      # write session cookies or per-user state.
      # Note: if responses vary by locale, set a `Vary: Accept-Language` header
      # or use a locale-specific cache key in your proxy config.
      pipeline :browser_render do
        plug(:set_locale)

        # detect Accept headers to serve JSON or HTML
        plug(Bonfire.UI.Common.Plugs.MaybeActivityRedirectPlug)

        plug(:put_root_layout,
          html: {Bonfire.UI.Common.LayoutView, :root},
          swiftui: {Bonfire.UI.Common.LayoutView.SwiftUI, :root},
          jetpack: {Bonfire.UI.Common.LayoutView.Jetpack, :root}
        )

        # FIXME: disabled because of compilation issues with phoenix_gon
        plug(PhoenixGon.Pipeline,
          # FIXME: this doesn't take into account runtime config
          assets: &Bonfire.UI.Common.Routes.gon_js_config/0
        )

        # LiveView Native support (deprecated)
        # Bonfire.UI.Common.Web.maybe_native_plug()

        # plug(:load_current_auth) # do we need this here?

        # plug Bonfire.UI.Me.Plugs.Locale # TODO: skip guessing a locale if the user has one in preferences
      end

      # Interactive-only additions on top of :browser_render. NOT safe for
      # caching: fetch_live_flash carries per-user flash messages.
      pipeline :browser_ui do
        plug(:browser_render)

        # plug Bonfire.UI.Common.Plugs.AllowTestSandbox

        plug(:fetch_live_flash)
      end

      # Standard interactive browser pipeline.
      pipeline :browser do
        plug(:basic)
        plug(:browser_accepts)
        plug(:browser_security)
        plug(:browser_ui)
      end

      # Like :browser but without CSRF — for routes that receive cross-origin
      # requests (e.g. ActivityPub inboxes, webhooks).
      pipeline :browser_unsafe do
        plug(:basic)
        plug(:browser_accepts)
        plug(:put_secure_browser_headers)
        plug(:fetch_live_flash)
      end

      # Rate-limits POST form submissions. Compose with :browser in a scope via
      # pipe_through([:browser, :throttle_forms]).
      pipeline :throttle_forms do
        plug(:basic)

        plug :rate_limit,
          method: "POST",
          key_prefix: :forms,
          scale_ms: 60_000,
          limit: if(Bonfire.Common.Config.env() in [:dev, :test], do: 90, else: 5)
      end

      # Base pipeline for public responses that CDNs and proxies may cache.
      # Use for non-HTML responses (SVG, JSON, images, etc.).
      # For full HTML pages with layout, use :cacheable_html instead.
      #
      # Includes :basic so the session can be read (allowing CacheControlPlug
      # to skip caching for authenticated users), and :browser_render for full HTML page rendering (locale, root layout, Gon JS config), but excludes :browser_security
      # so no CSRF cookie is written. As long as the session is not modified,
      # no Set-Cookie header is emitted.
      #
      # Use for controller actions or LiveView dead renders that return cacheable HTML. Cache-Control headers are NOT set here — add CacheControlPlug in each controller to choose TTL and purgeable options per route:
      #
      #   plug Bonfire.UI.Common.CacheControlPlug                    # defaults
      #   plug Bonfire.UI.Common.CacheControlPlug, purgeable: true   # longer TTLs
      #   plug Bonfire.UI.Common.CacheControlPlug, ttl: 3600         # explicit
      pipeline :cacheable do
        plug(:basic)
        plug(:browser_accepts)
        plug(:browser_render)
        plug(Bonfire.UI.Common.MaybeStaticGeneratorPlug)
      end

      # Convenience pipeline for public HTML pages that should be cached with
      # default TTLs and/or served from the static disk cache for guests.
      # Equivalent to :cacheable + CacheControlPlug with purgeable: false defaults.
      # Use :cacheable to define TTLs per-controller with an explicit CacheControlPlug plug.
      pipeline :cacheable_page do
        plug(:cacheable)
        plug(Bonfire.UI.Common.CacheControlPlug, purgeable: false)
      end

      # Hybrid pipeline for LiveView routes that should serve from the static
      # disk/memory cache for unauthenticated guests, while still providing the
      # full interactive browser experience for logged-in users.
      #
      # On a cache HIT (unauthenticated, no query string):
      #   MaybeStaticGeneratorPlug halts — no CSRF token or flash in the response,
      #   ensuring the cached HTML is safe to serve to any visitor.
      #
      # On a cache MISS or authenticated request:
      #   MaybeCSRFPlug applies protect_from_forgery only for authenticated users
      #   (so their LiveView socket can connect), skipping CSRF for unauthenticated
      #   users (so their fresh HTML can be written to the static cache cleanly).
      #   fetch_live_flash then runs; if flash is present, cacheable_response? will
      #   block writing that response to the static cache.
      #
      # Compose with a :cacheable_* pipeline (e.g. :cacheable_post) to set
      # cache-control and surrogate-key headers for the specific route.
      pipeline :browser_or_cacheable do
        plug(:basic)
        plug(:browser_accepts)
        # Security headers are response headers — safe to set even on cache hits
        # because they are NOT embedded in the cached HTML body.
        plug(:put_secure_browser_headers)
        plug(:browser_render)
        plug(Bonfire.UI.Common.MaybeStaticGeneratorPlug)
        # CSRF only for authenticated users — unauthenticated responses must be
        # CSRF-token-free to be safely written to the shared static cache.
        plug(Bonfire.UI.Common.Plugs.MaybeCSRFPlug)
        plug(:fetch_live_flash)
      end

      pipeline :static_generator do
        plug(:basic_html)
        plug(Bonfire.UI.Common.StaticGeneratorPlug)
      end

      scope "/#{Bonfire.UI.Common.StaticGenerator.base_path()}" do
        pipe_through(:static_generator)

        match(
          :*,
          "/*path",
          Bonfire.UI.Common.StaticFallbackController,
          :fallback
        )
      end

      # Apple Universal Links — serves the app-site-association file
      # so macOS/iOS opens https:// links in the desktop app
      scope "/.well-known" do
        get("/apple-app-site-association", Bonfire.UI.Common.AppleAppSiteAssociation, :show)
      end

      scope "/extensions/code/raw" do
        match(
          :*,
          "/*path",
          Bonfire.UI.Common.RawCodeController,
          :code
        )
      end

      scope "/extensions/docs" do
        match(
          :*,
          "/*path",
          Bonfire.UI.Common.RawCodeController,
          :docs
        )
      end

      # Public endpoints with no session — safe to cache at CDN level
      scope "/" do
        pipe_through(:cacheable)

        get("/gen_avatar", Bonfire.UI.Common.GenAvatar, :generate)
        get("/gen_avatar/:id", Bonfire.UI.Common.GenAvatar, :generate)
      end

      # pages anyone can view
      scope "/" do
        pipe_through(:browser)

        get("/guest/crash_test", Bonfire.UI.Common.ErrorController, :crash_test)
        get("/guest/error", Bonfire.UI.Common.ErrorController, as: :error_guest)
        get("/guest/error/:code", Bonfire.UI.Common.ErrorController, as: :error_guest)

        live("/crash_test", Bonfire.UI.Common.ErrorLive)
        live("/crash_test/:component", Bonfire.UI.Common.ErrorLive)

        pipe_through(:throttle_forms)

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
        # random_socket_id: Text.unique_integer()
      }
    )
  end
end
