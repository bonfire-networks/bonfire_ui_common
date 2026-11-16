defmodule Bonfire.UI.Common.CSPHeadersTest do
  @moduledoc """
  Pages carry a Content-Security-Policy. The directives that cannot break a page (no plugins, no `<base>` hijack, forms only post to us, framing only by us) are enforced. The `script-src` part is report-only until the inline scripts and handlers are gone, so a violation is logged by the browser but nothing is blocked.

  Routes that set their own policy (embeddable pages, the GraphiQL explorer) keep it and still get the enforced directives, rather than losing them.
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  defp header(conn, name), do: conn |> Plug.Conn.get_resp_header(name) |> Enum.join("; ")

  defp directive(policy, name) do
    policy
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.find(&String.starts_with?(&1, name <> " "))
  end

  for path <- ["/login", "/"] do
    test "GET #{path} sends the enforced directives and a report-only script policy" do
      conn = get(conn(), unquote(path))

      # control: the page itself rendered, with the secure headers and the directives Phoenix already sends
      assert conn.status in [200, 302]
      assert Plug.Conn.get_resp_header(conn, "x-content-type-options") == ["nosniff"]

      enforced = header(conn, "content-security-policy")
      assert directive(enforced, "base-uri") == "base-uri 'self'"
      assert directive(enforced, "frame-ancestors") =~ "'self'"

      assert directive(enforced, "object-src") == "object-src 'none'"
      assert directive(enforced, "form-action") == "form-action 'self'"

      # the script part must not be enforced yet: it would block our inline scripts
      refute enforced =~ "script-src"
      report_only = header(conn, "content-security-policy-report-only")
      assert directive(report_only, "script-src") =~ "'self'"
    end
  end

  test "an embeddable page keeps its own frame-ancestors and still gets the enforced directives" do
    user = fake_user!(fake_account!())

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "an embeddable post"}},
        boundary: "public"
      )

    conn = get(conn(), "/comments/embed/#{post.id}")

    # control: the embeddable page rendered and sets its own frame-ancestors, as before
    assert conn.status == 200

    enforced = header(conn, "content-security-policy")
    assert directive(enforced, "frame-ancestors")
    assert directive(enforced, "base-uri") == "base-uri 'self'"
    assert directive(enforced, "object-src") == "object-src 'none'"
    assert directive(enforced, "form-action") == "form-action 'self'"
  end

  test "the GraphiQL explorer keeps its own policy and still gets the enforced directives" do
    conn = get(conn(), "/api/explore/simple")

    # control: its own policy is still there
    enforced = header(conn, "content-security-policy")
    assert enforced =~ "cdn.jsdelivr.net"

    assert directive(enforced, "object-src") == "object-src 'none'"
    assert directive(enforced, "form-action") == "form-action 'self'"
  end
end
