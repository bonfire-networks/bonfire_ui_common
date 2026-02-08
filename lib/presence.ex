defmodule Bonfire.UI.Common.Presence do
  @moduledoc "WIP for tracking online users. Used by `PersistentLive`"
  use Phoenix.Presence,
    otp_app: :bonfire,
    pubsub_server: Bonfire.Common.PubSub

  import Untangle
  use Bonfire.Common.E
  alias Bonfire.UI
  alias Bonfire.Common.Utils

  @presence "bonfire:presence"

  @doc "Join a user to the list of those who are present"
  def present!(socket, meta \\ %{}) do
    if UI.Common.socket_connected?(socket) do
      user_id = Utils.current_user_id(socket)

      if user_id do
        {:ok, _} =
          track(
            self(),
            @presence,
            user_id,
            Enum.into(meta, %{
              # name: user_id[:name],
              pid: self(),
              joined_at: :os.system_time(:seconds)
            })
          )

        debug(user_id, "joined")
      else
        debug("skip because we have no user")
      end
    else
      debug("skip because socket not connected")
    end

    socket
  end

  @doc "Check if a given user (or the current user) is in the list of those who are present"
  def present?(user_id_or_context) do
    present_meta(user_id_or_context)
  end

  def present_meta(user_id_or_context) do
    if user_id =
         Utils.current_user_id(user_id_or_context) do
      get_by_key(
        @presence,
        user_id
      )
      |> e(:metas, [])

      # |> debug()
    end
  end

  def list() do
    list(@presence)
  end

  def list_and_maybe_subscribe_to_presence(socket) do
    if UI.Common.socket_connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, @presence)
    end

    socket
    |> Phoenix.Component.assign(:users, %{})
    |> handle_joins(list())
  end

  # act joins/leave if subscribed to them
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_joins(socket, joins) do
    Enum.reduce(joins, socket, fn {user, %{metas: [meta | _]}}, socket ->
      Phoenix.Component.assign(
        socket,
        :users,
        Map.put(e(UI.Common.assigns(socket), :users, %{}), user, meta)
      )
    end)
  end

  defp handle_leaves(socket, leaves) do
    Enum.reduce(leaves, socket, fn {user, _}, socket ->
      Phoenix.Component.assign(
        socket,
        :users,
        Map.delete(e(UI.Common.assigns(socket), :users, %{}), user)
      )
    end)
  end

  @doc """
  Put a value in the process dictionary of a user's PersistentLive process(es).
  Accepts a user_id or a pid directly.
  """
  def process_put(pid, key, value) when is_pid(pid) do
    send(pid, {:process_put, key, value})
  end

  def process_put(user_id, key, value) do
    (present_meta(user_id) || [])
    |> Enum.each(&send(&1.pid, {:process_put, key, value}))
  end

  @doc """
  Get a value from the process dictionary of a user's PersistentLive process.
  Accepts a user_id or a pid directly.
  """
  def process_get(pid, key, default \\ nil)

  def process_get(pid, key, default) when is_pid(pid) do
    GenServer.call(pid, {:process_get, key, default})
  end

  def process_get(user_id, key, default) do
    case present_meta(user_id) do
      [%{pid: pid} | _] -> GenServer.call(pid, {:process_get, key, default})
      _ -> default
    end
  end
end
