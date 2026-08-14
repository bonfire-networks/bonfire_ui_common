defmodule Bonfire.UI.Common.InstanceFaviconPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Bonfire.UI.Common.InstanceFaviconPlug

  test "redirects favicon.ico to a custom raster instance icon" do
    Process.put(
      [:bonfire, :ui, :theme, :instance_icon],
      "https://example.com/instance-icon.png"
    )

    conn =
      :get
      |> conn("/favicon.ico")
      |> InstanceFaviconPlug.call([])

    assert conn.halted
    assert conn.status == 302

    assert Plug.Conn.get_resp_header(conn, "location") == [
             "https://example.com/instance-icon.png"
           ]
  end

  test "lets the bundled favicon through when the instance icon is the Bonfire default" do
    Process.put(
      [:bonfire, :ui, :theme, :instance_icon],
      "/images/bonfire-icon.png"
    )

    conn =
      :get
      |> conn("/favicon.ico")
      |> InstanceFaviconPlug.call([])

    refute conn.halted
    assert conn.status == nil
  end

  test "does not redirect favicon.ico to itself" do
    # a very natural value for an admin to paste in, and the one this feature is about:
    # redirecting it to itself would loop until the browser gives up
    for icon <- ["favicon.ico", "/favicon.ico", "#{Bonfire.Common.URIs.base_url()}/favicon.ico"] do
      Process.put([:bonfire, :ui, :theme, :instance_icon], icon)

      conn =
        :get
        |> conn("/favicon.ico")
        |> InstanceFaviconPlug.call([])

      refute conn.halted, "expected #{icon} not to redirect /favicon.ico to itself"
      assert conn.status == nil
    end
  end

  test "declares the custom icon for browser and Apple touch metadata" do
    Process.put(
      [:bonfire, :ui, :theme, :instance_icon],
      "https://example.com/instance-icon.png"
    )

    html =
      :get
      |> conn("/")
      |> Bonfire.Web.Endpoint.include_assets(:top)

    assert html =~ ~s(<link rel="icon" href="https://example.com/instance-icon.png">)

    assert html =~
             ~s(<link rel="apple-touch-icon" href="https://example.com/instance-icon.png">)

    refute html =~ ~s(<link rel="apple-touch-icon" href="/pwa/ios/180.png">)
  end

  test "keeps the bundled Apple touch icon when the custom icon is an SVG" do
    # iOS ignores an SVG touch icon, so declaring one would silently degrade the home-screen
    # icon to a screenshot of the page (this is also what a failed SVG conversion leaves us with)
    Process.put([:bonfire, :ui, :theme, :instance_icon], "/images/no-such-logo.svg")

    html =
      :get
      |> conn("/")
      |> Bonfire.Web.Endpoint.include_assets(:top)

    assert html =~ ~s(<link rel="apple-touch-icon" href="/pwa/ios/180.png">)
  end

  test "escapes a custom icon before putting it in an href" do
    Process.put(
      [:bonfire, :ui, :theme, :instance_icon],
      "https://example.com/icon.png\"><script>alert(1)</script>"
    )

    html =
      :get
      |> conn("/")
      |> Bonfire.Web.Endpoint.include_assets(:top)

    refute html =~ "<script>alert(1)</script>"
    assert html =~ "&lt;script&gt;"
  end
end
