defmodule Bonfire.UI.Common.LivePlugs.AllowTestSandbox do
  use Bonfire.UI.Common.Web, :live_plug

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, _params, _session, socket) do
    # to use with LV :on_mount

    {:cont, allow_ecto_sandbox(socket) || socket}
  end

  def mount(_params, _session, socket) do
    # to use as LivePlug
    {:ok, allow_ecto_sandbox(socket) || socket}
  end

  defp allow_ecto_sandbox(socket) do
    if Bonfire.Common.Config.get(:sql_sandbox) do
      %{assigns: %{phoenix_ecto_sandbox: metadata}} =
        assign_new(socket, :phoenix_ecto_sandbox, fn ->
          if connected?(socket),
            do:
              get_connect_info(socket, :user_agent)
              |> debug("uaaa")
        end)

      Phoenix.Ecto.SQL.Sandbox.allow(metadata, Ecto.Adapters.SQL.Sandbox)

      socket
    end
  end
end
