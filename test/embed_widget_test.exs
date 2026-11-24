defmodule Bonfire.UI.Common.EmbedWidgetTest do
  @moduledoc "Any widget declared embeddable can be embedded on other sites from `/embed/widget/:id`, rendered as guests see it."
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  setup do
    # a custom widget, which is embeddable, as guests can see it
    Process.put([:bonfire_ui_common, Bonfire.UI.Common.Widgets, :custom], %{
      hello: %{title: "Embedded hello", text: "Hello from **the instance**"}
    })

    :ok
  end

  defp header(conn, name), do: conn |> Plug.Conn.get_resp_header(name) |> Enum.join("; ")

  test "an embeddable widget renders alone in the iframe layout, and other sites may frame it" do
    conn = get(conn(), "/embed/widget/custom_hello")

    doc = conn |> html_response(200) |> Floki.parse_document!()

    assert doc |> Floki.find("[data-widget-id=custom_hello]") |> Floki.text() =~
             "Hello from the instance"

    # only the widget: no app header or nav
    assert [_] = Floki.find(doc, "[data-widget-id]")

    # the iframe layout, which tells the parent page its height
    assert Floki.raw_html(doc) =~ "bonfire:iframe-resize"

    # framed by `frame-ancestors`, not refused by `x-frame-options`
    assert Plug.Conn.get_resp_header(conn, "x-frame-options") == []
    assert header(conn, "content-security-policy") =~ "frame-ancestors"
  end

  test "signed in, the embed still shows what guests see" do
    account = fake_account!()
    user = fake_user!(account)

    html =
      conn(user: user, account: account)
      |> get("/embed/widget/custom_hello")
      |> html_response(200)

    assert html =~ "Hello from"
    refute html =~ user.character.username
  end

  defp embed_box(path) do
    [box] =
      get(conn(), path)
      |> html_response(200)
      |> Floki.parse_document!()
      |> Floki.find("[data-role=embed_widget]")

    box
  end

  # LiveViewTest runs no JS: this checks the mark the iframe layout's script reads to send rich-text links to a new tab, as `LinkLive`s read `link_target`
  test "the embed marks its links to open in a new tab" do
    assert Floki.attribute(embed_box("/embed/widget/custom_hello"), "data-embed-links") == [
             "_blank"
           ]
  end

  test "?theme= themes the embed" do
    assert Floki.attribute(embed_box("/embed/widget/custom_hello?theme=dark"), "data-theme") ==
             ["dark"]
  end

  test "?width= caps the embed's width in pixels, 720 by default, or full for the frame's width" do
    for {query, max_width} <- [
          {"", "max-width: 720px"},
          {"?width=480", "max-width: 480px"},
          {"?width=full", nil}
        ] do
      style =
        embed_box("/embed/widget/custom_hello" <> query)
        |> Floki.attribute("style")
        |> Enum.join()

      if max_width,
        do: assert(style == max_width, query),
        else: refute(style =~ "max-width", query)
    end
  end

  test "a widget for signed-in people isn't served" do
    assert get(conn(), "/embed/widget/getting_started").status == 404
  end

  test "an unknown widget isn't served" do
    assert get(conn(), "/embed/widget/no_such_widget").status == 404
  end
end
