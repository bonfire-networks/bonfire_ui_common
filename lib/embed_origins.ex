defmodule Bonfire.UI.Common.EmbedOrigins do
  @moduledoc """
  The `IFRAME_ALLOWED_ORIGINS` allowlist, parsed the same way for both of its consumers — which need deliberately different strictness:

    * `frame_ancestors/0` returns the raw value for the CSP `frame-ancestors` directive (`Bonfire.UI.Common.Plugs.IframeEmbeddablePlug`). That's a CSP *source list*, so schemes, ports, wildcards and `'self'` are all meaningful there.
    * `allowed?/1` decides whether to mint a long-lived embed bearer token for a `go` URL after login (`Bonfire.UI.Me.LoginController`). That's an authorization decision about one concrete URL, so it does a strict full-origin match (scheme + host + port) and won't mint over plaintext.

  Format: space-separated origins, e.g. `"https://blog.example.com https://www.example.org"`. A bare hostname or `host:port` is read as https. A default port is equivalent to writing it out (`https://x` == `https://x:443`). CSP-only values like `*` or `'self'` never authorise minting.
  """

  @env "IFRAME_ALLOWED_ORIGINS"
  # http is only tolerated for local development (a token can't be sniffed off localhost)
  @local_hosts ~w(localhost 127.0.0.1 ::1)

  @doc "The raw `frame-ancestors` source list (CSP semantics). Defaults to `'self'`."
  def frame_ancestors, do: System.get_env(@env, "'self'")

  @doc """
  Whether `url`'s origin is on the allowlist, strictly enough to mint an embed token for.

  Compares scheme + host + port. Requires `https`, except for local development hosts.
  """
  def allowed?(url) when is_binary(url) do
    with {:ok, origin} <- origin(url),
         true <- mintable?(origin) do
      Enum.any?(allowed_origins(), &(&1 == origin))
    else
      _ -> false
    end
  end

  def allowed?(_), do: false

  defp allowed_origins do
    System.get_env(@env, "")
    |> String.split()
    |> Enum.flat_map(fn entry ->
      case origin(entry) do
        {:ok, origin} -> [origin]
        _ -> []
      end
    end)
  end

  # `{scheme, host, port}`, normalized: downcased (schemes/hosts are case-insensitive per RFC 3986)
  # and with the scheme's default port filled in, so `https://x` == `https://x:443`.
  defp origin(url) when is_binary(url) do
    url
    |> String.trim()
    |> ensure_scheme()
    |> case do
      nil ->
        :error

      url ->
        case URI.parse(url) do
          %URI{scheme: scheme, host: host, port: port}
          when is_binary(scheme) and is_binary(host) and host != "" ->
            scheme = String.downcase(scheme)
            {:ok, {scheme, String.downcase(host), port || URI.default_port(scheme)}}

          _ ->
            :error
        end
    end
  end

  defp origin(_), do: :error

  # A scheme-less entry (`blog.example.com`, `blog.example.com:8443`) is read as https. Must be
  # decided BEFORE URI.parse, which reads `blog.example.com:8443` as scheme="blog.example.com".
  # Anything that isn't a plain `host`/`host:port` (a CSP wildcard or `'self'`) isn't a concrete
  # origin, and is rejected.
  defp ensure_scheme(url) do
    cond do
      String.contains?(url, "://") -> url
      Regex.match?(~r{^[a-zA-Z0-9.\-]+(:\d+)?$}, url) -> "https://" <> url
      true -> nil
    end
  end

  defp mintable?({"https", _host, _port}), do: true
  defp mintable?({"http", host, _port}), do: host in @local_hosts
  defp mintable?(_), do: false
end
