defmodule Bonfire.UI.Common.Plugs.AllowTestSandbox do
  @moduledoc """
  Plug that allows Ecto sandbox access for controller processes during tests.
  Similar to LivePlugs.AllowTestSandbox but for regular HTTP requests.
  """

  @behaviour Plug
  import Plug.Conn
  use Bonfire.Common.Config
  import Untangle

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if Bonfire.Common.Config.get(:sql_sandbox, false) do
      allow_ecto_sandbox(conn)
    end || conn
  end

  defp allow_ecto_sandbox(conn) do
    # Mirror the LiveView approach - look for sandbox metadata in user agent
    case conn.private[:phoenix_ecto_sandbox] || get_req_header(conn, "user-agent") do
      [user_agent] ->
        # Check if this is a test request with sandbox metadata
        if user_agent do
          try do
            debug(user_agent, "PHX allow_ecto_sandbox with metadata from user agent")
            Phoenix.Ecto.SQL.Sandbox.allow(user_agent, Ecto.Adapters.SQL.Sandbox)
          rescue
            error ->
              err(error, "failed to allow sandbox access")
              nil
          end
        end

      other ->
        debug(other, "no user agent found")
        nil
    end
  end
end
