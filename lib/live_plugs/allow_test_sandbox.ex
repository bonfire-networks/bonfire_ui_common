defmodule Bonfire.UI.Common.LivePlugs.AllowTestSandbox do
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    # to use with LV :on_mount
    allow_ecto_sandbox(socket)
    {:cont, socket}
  end

  def mount(_params, _session, socket) do
    # to use as LivePlug
    allow_ecto_sandbox(socket)
    {:ok, socket}
  end

  defp allow_ecto_sandbox(socket) do
    if Bonfire.Common.Config.get(:sql_sandbox) do
      %{assigns: %{phoenix_ecto_sandbox: metadata}} =
        assign_new(socket, :phoenix_ecto_sandbox, fn ->
          if connected?(socket), do: get_connect_info(socket, :user_agent)
        end)

      Phoenix.Ecto.SQL.Sandbox.allow(metadata, Ecto.Adapters.SQL.Sandbox)
    end
  end
end
