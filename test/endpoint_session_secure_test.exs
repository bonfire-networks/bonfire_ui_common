defmodule Bonfire.UI.Common.EndpointSessionSecureTest do
  @moduledoc "The session cookie is only sent over https when the public URL is https, whatever its port."
  use ExUnit.Case, async: false
  @moduletag :ui

  alias Bonfire.UI.Common.EndpointTemplate

  setup do
    original = Application.get_env(:bonfire, Bonfire.Web.Endpoint, [])
    on_exit(fn -> Application.put_env(:bonfire, Bonfire.Web.Endpoint, original) end)
    {:ok, original: original}
  end

  defp secure_with(url, original) do
    Application.put_env(:bonfire, Bonfire.Web.Endpoint, Keyword.put(original, :url, url))
    EndpointTemplate.session_options()[:secure]
  end

  test "an https public URL on a port other than 443 is secure", %{original: original} do
    assert secure_with([host: "example.com", scheme: "https", port: 8443], original) == true
  end

  test "port 443 is secure", %{original: original} do
    assert secure_with([host: "example.com", port: 443], original) == true
  end

  test "an http public URL is not secure", %{original: original} do
    assert secure_with([host: "example.com", scheme: "http", port: 8443], original) == false
    assert secure_with([host: "example.com", port: 4000], original) == false
  end
end
