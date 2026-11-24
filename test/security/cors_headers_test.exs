defmodule Bonfire.UI.Common.CORSHeadersTest do
  @moduledoc """
  Mastodon client apps that run in a browser (Phanpy, Elk) read some public resources from the instance cross-origin, and the browser lets them only if the answer carries `Access-Control-Allow-Origin`. Uploaded media is covered in `bonfire_files` (`uploads_cors_test.exs`); these are the ones configured here: the default avatar (a static image, `endpoint_template.ex`) and nodeinfo discovery (`cors_routes`, `runtime_config.ex`).
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  @client_origin "https://phanpy.social"

  defp from_client_app, do: conn() |> Plug.Conn.put_req_header("origin", @client_origin)

  defp assert_cors_allowed(conn) do
    assert [allowed] = Plug.Conn.get_resp_header(conn, "access-control-allow-origin")
    assert allowed in ["*", @client_origin]
  end

  # users without an avatar of their own get this one in the Mastodon API
  test "the default avatar answers a client app's origin" do
    served = get(from_client_app(), "/images/avatar.png")

    assert served.status == 200
    assert_cors_allowed(served)
  end

  # client apps read it to learn what the instance runs (Phanpy does on login)
  test "nodeinfo discovery answers a client app's origin" do
    served = get(from_client_app(), "/.well-known/nodeinfo")

    assert served.status == 200
    assert_cors_allowed(served)
  end
end
