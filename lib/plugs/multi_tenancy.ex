defmodule Bonfire.UI.Common.MultiTenancyPlug do
  @behaviour Plug
  # import Untangle

  @impl true
  def init(_opts) do
    []
  end

  @impl true
  def call(%{private: %{phoenix_endpoint: phoenix_endpoint}} = conn, _opts) do
    Bonfire.Common.TestInstanceRepo.maybe_declare_test_instance(phoenix_endpoint)
    conn
  end

  def call(conn, _opts) do
    conn
  end
end
