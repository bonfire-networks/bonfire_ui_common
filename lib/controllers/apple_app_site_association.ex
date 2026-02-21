defmodule Bonfire.UI.Common.AppleAppSiteAssociation do
  @moduledoc """
  Serves the `/.well-known/apple-app-site-association` JSON so that macOS/iOS Universal Links open in a native app instead of Safari.

  The response is generated dynamically from config:

    - `APPLE_TEAM_ID` env var (required — 10-char Apple Developer Team ID which must match the one used to sign the app)
    - `APPLE_APP_BUNDLE_ID` env var (optional, defaults to `cafe.bonfire.desktop` which must match the app's bundle identifier)

  If `APPLE_TEAM_ID` is not set the endpoint returns 404.
  """
  use Bonfire.UI.Common.Web, :controller

  def show(conn, _params) do
    team_id = System.get_env("APPLE_TEAM_ID")
    bundle_id = System.get_env("APPLE_APP_BUNDLE_ID", "cafe.bonfire.desktop")

    if team_id do
      payload = %{
        applinks: %{
          details: [
            %{
              appIDs: ["#{team_id}.#{bundle_id}"],
              components: [
                # Feeds
                %{"/" => "/feed"},
                %{"/" => "/feed/*"},
                %{"/" => "/notifications"},
                %{"/" => "/bookmarks"},
                # Content
                %{"/" => "/post/*"},
                %{"/" => "/discussion/*"},
                # Profiles
                %{"/" => "/@*"},
                %{"/" => "/user/*"},
                %{"/" => "/profile/*"},
                # Messages & chat
                %{"/" => "/messages"},
                %{"/" => "/messages/*"},
                %{"/" => "/message/*"},
                # Groups
                %{"/" => "/groups"},
                %{"/" => "/group/*"},
                %{"/" => "/&*"},
                # Topics
                %{"/" => "/topics"},
                %{"/" => "/topics/*"},
                %{"/" => "/+*"},
                # Search
                %{"/" => "/search"},
                %{"/" => "/search/*"},
                # ActivityPub objects
                %{"/" => "/pub/objects/*"}
              ]
            }
          ]
        }
      }

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(payload))
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, Jason.encode!(%{error: "APPLE_TEAM_ID not configured"}))
    end
  end
end
