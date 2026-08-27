defmodule Bonfire.UI.Common.EmbedOriginsTest do
  @moduledoc """
  `host_allowed?/1` is the looser, host-only allowlist check used to decide whether a guest-loaded
  embed may create a thread anchor for a URL (the operator only needs to approve the domain). It
  must stay distinct from the strict `allowed?/1` used to mint login bearer tokens.
  """
  use ExUnit.Case, async: false

  alias Bonfire.UI.Common.EmbedOrigins

  @env "IFRAME_ALLOWED_ORIGINS"

  defp with_allowlist(value, fun) do
    prev = System.get_env(@env)
    System.put_env(@env, value)

    try do
      fun.()
    after
      if prev, do: System.put_env(@env, prev), else: System.delete_env(@env)
    end
  end

  describe "host_allowed?/1 (anchor creation)" do
    test "matches an approved domain across any scheme, port and path" do
      with_allowlist("blog.example.com https://www.other.org", fn ->
        assert EmbedOrigins.host_allowed?("https://blog.example.com/a/post/")
        assert EmbedOrigins.host_allowed?("http://blog.example.com:8080/x")
        assert EmbedOrigins.host_allowed?("https://www.other.org/y")
      end)
    end

    test "rejects a host that is not on the list (no subdomain wildcarding)" do
      with_allowlist("blog.example.com", fn ->
        refute EmbedOrigins.host_allowed?("https://evil.blog.example.com/x")
        refute EmbedOrigins.host_allowed?("https://example.com/x")
      end)
    end

    test "CSP-only values never qualify as concrete hosts" do
      with_allowlist("*", fn ->
        refute EmbedOrigins.host_allowed?("https://anything.example.com/")
      end)

      with_allowlist("'self'", fn ->
        refute EmbedOrigins.host_allowed?("https://anything.example.com/")
      end)
    end

    test "unset / empty allowlist allows nothing, and junk input is false" do
      with_allowlist("", fn ->
        refute EmbedOrigins.host_allowed?("https://blog.example.com/")
        refute EmbedOrigins.host_allowed?("not a url")
        refute EmbedOrigins.host_allowed?(nil)
      end)
    end
  end

  describe "allowed?/1 (token minting) stays strict" do
    test "requires an exact https origin, so a bare host or http does not authorise minting" do
      with_allowlist("blog.example.com", fn ->
        # host_allowed? matches the domain, but the strict token check requires the full https origin
        assert EmbedOrigins.host_allowed?("https://blog.example.com/x")
        assert EmbedOrigins.allowed?("https://blog.example.com/x")
        refute EmbedOrigins.allowed?("http://blog.example.com/x")
        refute EmbedOrigins.allowed?("https://blog.example.com:8080/x")
      end)
    end
  end
end
