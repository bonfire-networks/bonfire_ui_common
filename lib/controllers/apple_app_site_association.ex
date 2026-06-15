defmodule Bonfire.UI.Common.AppleAppSiteAssociation do
  @moduledoc """
  Serves the `/.well-known/apple-app-site-association` JSON so that macOS/iOS Universal Links open in a native app instead of Safari.

  The response is generated dynamically from config:

    - `APPLE_TEAM_ID` env var (required — 10-char Apple Developer Team ID which must match the one used to sign the app)
    - `APPLE_APP_BUNDLE_ID` env var (optional, defaults to `cafe.bonfire.desktop,cafe.bonfire.app`).
      Accepts a comma-separated list so a single instance can serve Universal Links for both the
      desktop (`cafe.bonfire.desktop`) and mobile (`cafe.bonfire.app`) apps; each bundle id must
      match a `<team_id>.<bundle_id>` App ID signed with `APPLE_TEAM_ID`.

  If `APPLE_TEAM_ID` is not set the endpoint returns 404.
  """
  use Bonfire.UI.Common.Web, :controller

  def show(conn, _params) do
    team_id = System.get_env("APPLE_TEAM_ID")

    bundle_ids =
      System.get_env("APPLE_APP_BUNDLE_ID", "cafe.bonfire.desktop,cafe.bonfire.app")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

    if team_id do
      payload = %{
        applinks: %{
          details: [
            %{
              appIDs: Enum.map(bundle_ids, &"#{team_id}.#{&1}"),
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
