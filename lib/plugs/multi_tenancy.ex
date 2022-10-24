defmodule Bonfire.UI.Common.MultiTenancyPlug do
  @behaviour Plug
  import Untangle

  @impl true
  def init(_opts) do
    []
  end

  @impl true
  def call(%{private: %{phoenix_endpoint: Bonfire.Web.FakeRemoteEndpoint}} = conn, _opts) do
    Process.put(:phoenix_endpoint_module, Bonfire.Web.FakeRemoteEndpoint)
    Process.put(:ecto_repo_module, Bonfire.Common.TestInstanceRepo)
    info(self())
    conn
  end

  def call(conn, _opts) do
    conn
  end
end
