defmodule Bonfire.UI.Common.MultiTenancyPlug do
  @behaviour Plug
  # import Untangle

  @impl true
  def init(_opts) do
    []
  end

  # only needed for federation testing (running a fake second instance in the same BEAM)
  @enabled Application.compile_env(:bonfire, :env) == :test

  @impl true
  
  if @enabled do
    def call(%{private: %{phoenix_endpoint: phoenix_endpoint}} = conn, _opts) do
      Bonfire.Common.TestInstanceRepo.maybe_declare_test_instance(phoenix_endpoint)
      conn
    end
  end

  def call(conn, _opts) do
    conn
  end
end
