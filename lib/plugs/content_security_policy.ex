defmodule Bonfire.UI.Common.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Adds to the response's `content-security-policy` header the directives that cannot break a page, and sends the script policy as `content-security-policy-report-only`, so a browser logs what an enforced policy would block without blocking it.

  Enforced: no plugins (`object-src 'none'`), no `<base>` hijack, forms only post to this instance, and images, media and frames only over https (remote avatars, media and oEmbed come from other servers). Report-only: scripts only from this instance and the CDNs the app loads from. It stays report-only until the inline scripts and handlers are gone, because an enforced policy that allows them would protect little.

  Use after `put_secure_browser_headers`. Directives already in the header (Phoenix's `base-uri` and `frame-ancestors`, or a route's own policy) are kept, only missing ones are added. A plug that sets a directive of its own afterwards uses `put_directive/4`, so it does not replace the rest of the policy.

  The script sources can be set in config: `config :bonfire_ui_common, :csp_script_sources, ["'self'", "https://example.local"]`.
  """

  import Plug.Conn
  require Bonfire.Common.Config

  @enforced [
    {"object-src", "'none'"},
    {"base-uri", "'self'"},
    {"form-action", "'self'"},
    {"frame-ancestors", "'self'"},
    {"img-src", "'self' data: blob: https:"},
    {"media-src", "'self' data: blob: https:"},
    {"frame-src", "'self' https:"}
  ]

  # `'self'` plus the CDNs the app loads scripts from
  @script_sources [
    "'self'",
    "https://unpkg.com",
    "https://cdn.jsdelivr.net",
    "https://cdn.quilljs.com",
    "https://api.mapbox.com"
  ]

  @enforced_header "content-security-policy"
  @report_only_header "content-security-policy-report-only"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> add_missing(@enforced_header, @enforced)
    |> add_missing(@report_only_header, [{"script-src", script_sources()}])
  end

  @doc "Sets one directive of a policy header (the enforced one unless named), replacing that directive if it is there and keeping the others."
  def put_directive(conn, header \\ @enforced_header, name, value) do
    directives =
      conn
      |> directives(header)
      |> List.keystore(name, 0, {name, value})

    put_resp_header(conn, header, serialize(directives))
  end

  defp add_missing(conn, header, wanted) do
    existing = directives(conn, header)

    missing = Enum.reject(wanted, fn {name, _} -> List.keymember?(existing, name, 0) end)

    put_resp_header(conn, header, serialize(existing ++ missing))
  end

  defp directives(conn, header) do
    conn
    |> get_resp_header(header)
    |> Enum.join(";")
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn directive ->
      case String.split(directive, " ", parts: 2) do
        [name, value] -> {name, value}
        [name] -> {name, ""}
      end
    end)
  end

  defp serialize(directives),
    do: Enum.map_join(directives, "; ", fn {name, value} -> String.trim("#{name} #{value}") end)

  defp script_sources do
    Bonfire.Common.Config.get([:bonfire_ui_common, :csp_script_sources], @script_sources)
    |> Enum.join(" ")
  end
end
