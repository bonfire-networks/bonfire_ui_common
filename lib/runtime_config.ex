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

    config :bonfire_ui_common, :cors_routes, [
      # NOTE: the order matters, as the origins of the first matching route will be used
      %{
        paths: "/pub/actors/",
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
        paths: ["/api/v1", "/api/v2", "/api/v3"],
        origins:
          ([url, System.get_env("API_REST_CORS_ORIGIN")] ++ extra_api_origins)
          |> Enum.reject(&(is_nil(&1) or &1 == ""))
      },
      %{
        paths: ["/.well-known/oauth-authorization-server", "/.well-known/openid-configuration"],
        origins: "*"
      },
      %{
        paths: "/",
        origins: []
      }
    ]
  end
end
