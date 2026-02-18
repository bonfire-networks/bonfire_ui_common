defmodule Bonfire.UI.Common.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @doc """
  NOTE: you can override this default config in your app's `runtime.exs`, by placing similarly-named config keys below the `Bonfire.Common.Config.LoadExtensionsConfig.load_configs()` line
  """
  def config do
    import Config

    hostname = System.get_env("HOSTNAME", "localhost")
    port = System.get_env("PUBLIC_PORT", "4000")

    url =
      case port do
        "80" -> "http://#{hostname}"
        "443" -> "https://#{hostname}"
        _ -> "http://#{hostname}:#{port}"
      end

    extra_api_origins =
      System.get_env("API_CORS_ORIGINS_EXTRAS", "")
      |> String.split(",")
      |> Enum.filter(&(&1 != ""))

    # Page load profiler (disabled by default)
    config :bonfire_ui_common, Bonfire.UI.Common.PageTimingStorage,
      enabled: System.get_env("PAGE_PROFILER_ENABLED") in ~w(true yes 1),
      max_entries: String.to_integer(System.get_env("PAGE_PROFILER_MAX_ENTRIES", "500"))

    config :bonfire_ui_common, :cors_routes, [
      # NOTE: the order matters, as the origins of the first matching route will be used
      %{
        paths: [
          "/pub/actors/",
          "/.well-known/oauth-authorization-server",
          "/.well-known/openid-configuration",
          "/.well-known/webfinger",
          "/openid/register",
          "/oauth/token"
        ],
        origins: "*"
      },
      %{
        paths: "/pub",
        origins:
          ([url, System.get_env("API_ACTIVITYPUB_CORS_ORIGIN")] ++ extra_api_origins)
          |> Enum.reject(&(is_nil(&1) or &1 == ""))
      },
      %{
        paths: "/api/graphql",
        origins:
          ([url, System.get_env("API_GRAPHQL_CORS_ORIGIN")] ++ extra_api_origins)
          |> Enum.reject(&(is_nil(&1) or &1 == ""))
      },
      %{
        paths: "/api/",
        origins:
          ([url, System.get_env("API_REST_CORS_ORIGIN")] ++ extra_api_origins)
          |> Enum.reject(&(is_nil(&1) or &1 == ""))
      },
      %{
        paths: "/",
        origins: []
      }
    ]

    ## HTTP Caching - Environment variables
    # - `CACHE_PURGE_ADAPTERS` — comma-separated adapter names or fully-qualified module names.
    #   Recognised short names: `varnish`, `nginx`, `cloudflare`, `null`.
    #   Auto-detected from credentials if not set.
    # - `VARNISH_URL` — enables Varnish adapter (default: `http://localhost:80`)
    # - `NGINX_URL` — enables Nginx adapter (default: `http://localhost:80`); requires the `ngx_cache_purge` module or Nginx Plus — see `Bonfire.UI.Common.Cache.HTTPPurge.Nginx` for details.
    # - `CLOUDFLARE_ZONE_ID` + `CLOUDFLARE_API_TOKEN` — enables Cloudflare adapter

    varnish_url = System.get_env("VARNISH_URL")
    nginx_url = System.get_env("NGINX_URL")
    cf_zone = System.get_env("CLOUDFLARE_ZONE_ID")
    cf_token = System.get_env("CLOUDFLARE_API_TOKEN")

    config :bonfire_common, Bonfire.Common.Cache.HTTPPurge,
      adapters: resolve_http_purge_adapters(varnish_url, nginx_url, cf_zone, cf_token),
      varnish_url: varnish_url || "http://localhost:80",
      nginx_url: nginx_url || "http://localhost:80",
      cloudflare_zone_id: cf_zone,
      cloudflare_api_token: cf_token

    config :bonfire_ui_common, Bonfire.UI.Common.MaybeStaticGeneratorPlug,
      # store cached files in memory when they get hit often (0 meams disabled)
      memory_cache_threshold:
        System.get_env("STATIC_GENERATE_MEMORY_CACHE_THRESHOLD", "0") |> String.to_integer()
  end

  defp resolve_http_purge_adapters(varnish_url, nginx_url, cf_zone, cf_token) do
    case System.get_env("CACHE_PURGE_ADAPTERS") do
      env when env not in [nil, ""] ->
        env
        |> String.split(",", trim: true)
        |> Enum.flat_map(fn str ->
          adapter =
            case String.trim(str) do
              "varnish" -> Bonfire.UI.Common.Cache.HTTPPurge.Varnish
              "nginx" -> Bonfire.UI.Common.Cache.HTTPPurge.Nginx
              "cloudflare" -> Bonfire.UI.Common.Cache.HTTPPurge.Cloudflare
              "static_generator" -> Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator
              "null" -> Bonfire.Common.Cache.HTTPPurge.Null
              other -> Bonfire.Common.Types.maybe_to_module(other, false)
            end

          if is_atom(adapter) and not is_nil(adapter), do: [adapter], else: []
        end)
        |> case do
          [] -> [Bonfire.Common.Cache.HTTPPurge.Null]
          adapters -> adapters
        end

      _ ->
        # Auto-detect from presence of credentials
        detected =
          [
            {varnish_url, Bonfire.UI.Common.Cache.HTTPPurge.Varnish},
            {nginx_url, Bonfire.UI.Common.Cache.HTTPPurge.Nginx},
            {cf_zone && cf_token, Bonfire.UI.Common.Cache.HTTPPurge.Cloudflare}
          ]
          |> Enum.flat_map(fn
            {nil, _} -> []
            {false, _} -> []
            {_, adapter} -> [adapter]
          end)

        if detected == [], do: [Bonfire.Common.Cache.HTTPPurge.Null], else: detected
    end
  end
end
