defmodule Bonfire.UI.Common.ErrorPageTest do
  @moduledoc """
  The endpoint's error page is sent for a request in any format, such as a fetch from another fediverse server with an ActivityPub `Accept`, and never fails itself, which would leave the request with no answer.
  """
  use Bonfire.UI.Common.ConnCase, async: true
  @moduletag :ui

  # as the endpoint does when a request fails: render the error page with its `render_errors` config, then raise the failure again
  defp error_page_for(accept) do
    conn =
      build_conn(:get, "/")
      |> put_req_header("accept", accept)
      |> Phoenix.Controller.accepts(~w(html activity+json json ld+json))
      |> put_private(:phoenix_endpoint, Bonfire.Web.Endpoint)

    assert_error_sent(500, fn ->
      Phoenix.Endpoint.RenderErrors.__catch__(
        conn,
        :error,
        %RuntimeError{message: "a failure"},
        [],
        Bonfire.Web.Endpoint.config(:render_errors)
      )
    end)
  end

  test "is sent as HTML to a browser" do
    # the positive first: the page this helper gets is the endpoint's real error page
    assert {500, _headers, body} = error_page_for("text/html")
    assert body =~ ~s(id="layout-error")
  end

  for accept <- [
        "application/activity+json",
        ~s(application/ld+json; profile="https://www.w3.org/ns/activitystreams"),
        "application/json"
      ] do
    test "is sent for a request that accepts `#{accept}`" do
      assert {500, _headers, body} = error_page_for(unquote(accept))
      assert body != ""
    end
  end
end
