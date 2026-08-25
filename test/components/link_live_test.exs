defmodule Bonfire.UI.Common.LinkLiveTest do
  @moduledoc """
  Link rendering per URI scheme.

  `<.link>` RAISES on any scheme outside `Phoenix.LiveView.Utils`'s `@valid_uri_schemes` (a guard against `javascript:`), and its `navigate` accepts paths and http(s) ONLY. Links come from federated content, so a remote `gemini:`/`magnet:` URL, or a plain `mailto:` at the default target, used to raise mid-render and take out the whole activity:

      ** (ArgumentError) unsupported scheme given to <.link>
          (phoenix_live_view) lib/phoenix_live_view/utils.ex:588
          lib/components/links/link_live.ex:327 Bonfire.UI.Common.LinkLive.do_render_link/1
          deps/bonfire_ui_social/…/media_link_live.sface:6 MediaLinkLive.render/1
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Bonfire.UI.Common.LinkLive

  # a Surface stateless component is a function component, not a LiveComponent, so render `render/1` rather than the module (prop defaults still get filled, by the wrapper `SurfLiveAttr` puts around it)
  defp render_link(to, opts \\ []) do
    render_component(&LinkLive.render/1, Keyword.merge([to: to, label: "the label"], opts))
  end

  describe "schemes LiveView can navigate to" do
    test "a path uses live navigation" do
      html = render_link("/some/path")

      assert html =~ ~s|href="/some/path"|
      assert html =~ "data-phx-link"
    end

    test "an http(s) URL is still rendered as a link" do
      assert render_link("https://example.com/thing") =~ ~s|href="https://example.com/thing"|
    end

    test "an explicit target renders a plain href, without live navigation" do
      html = render_link("https://example.com/thing", target: "_blank")

      assert html =~ ~s|target="_blank"|
      refute html =~ "data-phx-link"
    end
  end

  describe "schemes that are valid in an href but NOT navigable" do
    # these reached the `navigate` clause at the default target and raised
    for scheme <- ["mailto:someone@example.com", "tel:+15551234", "xmpp:someone@example.com"] do
      test "#{scheme} renders as a link instead of raising" do
        html = render_link(unquote(scheme))

        assert html =~ ~s|href="#{unquote(scheme)}"|
        # live navigation would reject it, so it must not be used here
        refute html =~ "data-phx-link"
        assert html =~ "the label"
      end
    end
  end

  describe "schemes Phoenix doesn't list (federated content)" do
    for to <- [
          "gemini://example.org/page",
          "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
          "magnet:?xt=urn:btih:abcdef",
          "matrix:u/someone:example.org"
        ] do
      test "#{to} stays a working link rather than crashing the render" do
        html = render_link(unquote(to))

        assert html =~ ~s|href="#{unquote(to)}"|
        assert html =~ "the label"
      end
    end
  end

  describe "schemes that could execute in the page" do
    for to <- [
          "javascript:alert(1)",
          "JavaScript:alert(1)",
          "data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==",
          "vbscript:msgbox(1)"
        ] do
      test "#{to} is shown as plain text, never as an href" do
        html = render_link(unquote(to))

        assert html =~ "the label"
        assert html =~ "no_link"
        refute html =~ "href="
      end
    end
  end
end
