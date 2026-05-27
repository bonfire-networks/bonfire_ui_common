defmodule Bonfire.UI.Common.MaybePlausibleProxyPlug do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:bonfire_ui_common, :plausible_proxy, [])

    if config[:enabled] do
      PlausibleProxy.Plug.call(
        conn,
        PlausibleProxy.Plug.init(
          local_path: config[:local_path] || "/js/plausible_script.js",
          script_extension: config[:script_extension] || "script.js"
        )
      )
    else
      conn
    end
  end
end
