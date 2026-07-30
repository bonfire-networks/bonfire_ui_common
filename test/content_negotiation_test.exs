defmodule Bonfire.UI.Common.ContentNegotiationTest do
  @moduledoc "Doctests for `Bonfire.UI.Common.http_accepts?/2`, used by LiveViews to serve markdown/RSS variants of a browser page (see `save_accept_header/2` in `Bonfire.UI.Common.EndpointTemplate`, which puts the header in the session)."
  use ExUnit.Case, async: true

  doctest Bonfire.UI.Common, only: [http_accepts?: 2], import: true

  @moduletag :ui

  test "matches a media type listed among others in the header" do
    session = %{"accept_header" => "text/html;q=0.9,text/markdown;q=0.8,*/*;q=0.1"}

    assert Bonfire.UI.Common.http_accepts?(session, "text/markdown")
    assert Bonfire.UI.Common.http_accepts?(session, "text/html")
    refute Bonfire.UI.Common.http_accepts?(session, "application/rss+xml")
  end

  test "is false when the session carries no accept header" do
    refute Bonfire.UI.Common.http_accepts?(%{"accept_header" => nil}, "text/markdown")
    refute Bonfire.UI.Common.http_accepts?(%{}, "text/markdown")
  end
end
