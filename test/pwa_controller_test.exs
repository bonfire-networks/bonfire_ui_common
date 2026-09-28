defmodule Bonfire.UI.Common.PWAControllerTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Bonfire.UI.Common.PWAController

  defp manifest_json do
    conn =
      :get
      |> conn("/pwa/manifest.webmanifest")
      |> PWAController.manifest(%{})

    assert conn.status == 200
    assert ["application/manifest+json" <> _] = Plug.Conn.get_resp_header(conn, "content-type")

    Jason.decode!(conn.resp_body)
  end

  test "both endpoints are routed" do
    for {path, action} <- [{"/pwa/manifest.webmanifest", :manifest}, {"/pwa/open", :open}] do
      assert %{plug: PWAController, plug_opts: ^action} =
               Phoenix.Router.route_info(Bonfire.Web.Router, "GET", path, "localhost")
    end
  end

  describe "manifest" do
    test "names the installed app after the instance" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "Campfire Collective")
      Process.put([:bonfire, :ui, :theme, :instance_description], "A cosy corner")

      manifest = manifest_json()

      assert manifest["name"] == "Campfire Collective"
      assert manifest["short_name"] == "Campfire Collective"
      assert manifest["description"] == "A cosy corner"
    end

    test "falls back to Bonfire's name when the instance has none" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "")

      assert manifest_json()["short_name"] == "Bonfire"
    end

    test "gives iOS the same name as the manifest" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "Campfire Collective")

      html =
        :get
        |> conn("/")
        |> Bonfire.Web.Endpoint.include_assets(:top)

      assert html =~ ~s(<meta name="apple-mobile-web-app-title" content="Campfire Collective">)
      assert html =~ ~s(<link rel="manifest" href="/pwa/manifest.webmanifest" />)
    end

    test "keeps the bundled icons for a custom icon of unknown size" do
      # browsers skip an icon whose declared size is wrong, so one we haven't measured can't
      # replace the ones we have
      Process.put(
        [:bonfire, :ui, :theme, :instance_icon],
        "https://example.com/instance-icon.png"
      )

      icons = manifest_json()["icons"]

      assert Enum.any?(icons, &(&1["purpose"] == "maskable"))
      refute Enum.any?(icons, &(&1["src"] == "https://example.com/instance-icon.png"))
    end

    test "protocol handlers use schemes browsers accept, and point at the open route" do
      # custom schemes without a `web+` prefix are silently dropped
      for handler <- manifest_json()["protocol_handlers"] do
        assert String.starts_with?(handler["protocol"], "web+")
        assert handler["url"] == "/pwa/open?uri=%s"
      end
    end
  end

  describe "open" do
    test "looks up an ActivityPub link through search, so remote objects get fetched" do
      assert PWAController.open_path("web+ap://mastodon.social/@alice") ==
               "/search?s=https%3A%2F%2Fmastodon.social%2F%40alice"

      assert PWAController.open_path("web+activitypub://example.com/objects/1") ==
               "/search?s=https%3A%2F%2Fexample.com%2Fobjects%2F1"
    end

    test "never redirects off the instance" do
      for uri <- ["https://evil.example/", "//evil.example", "javascript:alert(1)", ""] do
        assert PWAController.open_path(uri) == "/"
      end
    end

    test "redirects to the local path" do
      conn =
        :get
        |> conn("/pwa/open?uri=web%2Bap%3A%2F%2Fmastodon.social%2F%40alice")
        |> Plug.Conn.fetch_query_params()
        |> then(&PWAController.open(&1, &1.query_params))

      assert conn.status == 302

      assert Plug.Conn.get_resp_header(conn, "location") == [
               "/search?s=https%3A%2F%2Fmastodon.social%2F%40alice"
             ]
    end
  end
end
