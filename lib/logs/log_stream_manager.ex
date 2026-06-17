defmodule Bonfire.UI.Common.LogStreamManager do
  @moduledoc """
  Owns the lifecycle of `Bonfire.UI.Common.LogStreamHandler` and the live (shared) filter for
  the admin log-streaming LiveDashboard page.

  The `:logger` handler is attached **only while at least one viewer has the page open** (ref
  counted via process monitors) and **only when the `LIVE_DASHBOARD_LOGGER` env is `"true"`**
  — the same flag that already gates the Request Logger. When no one is watching, there is
  zero logging overhead.

  The filter is global (one handler), so it is shared across simultaneous viewers; changes are
  broadcast as `{:log_filter_changed, filter}` on `LogStreamHandler.topic/0` so every open page
  reflects the currently-applied filter.
  """

  use GenServer
  alias Bonfire.UI.Common.LogStreamHandler

  @default_filter %{level: :info, query: nil, modules: nil}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Whether log streaming is allowed in this environment (gated by `LIVE_DASHBOARD_LOGGER`)."
  def enabled?, do: System.get_env("LIVE_DASHBOARD_LOGGER") == "true"

  @doc "Register the calling LiveView process as a viewer; attaches the handler on the first viewer."
  def viewer_joined(pid \\ self()) do
    GenServer.cast(__MODULE__, {:viewer_joined, pid})
  catch
    :exit, _ -> :ok
  end

  @doc "Update the shared source filter and push it into the running handler."
  def set_filter(filter) when is_map(filter) do
    GenServer.cast(__MODULE__, {:set_filter, filter})
  catch
    :exit, _ -> :ok
  end

  @doc "The currently-applied (shared) filter, so a newly-opened page can show it."
  def current_filter do
    GenServer.call(__MODULE__, :current_filter)
  catch
    :exit, _ -> @default_filter
  end

  @impl true
  def init(_opts) do
    {:ok, %{viewers: %{}, filter: @default_filter, attached?: false}}
  end

  @impl true
  def handle_call(:current_filter, _from, state) do
    {:reply, state.filter, state}
  end

  @impl true
  def handle_cast({:viewer_joined, pid}, state) do
    if Map.has_key?(state.viewers, pid) do
      {:noreply, state}
    else
      ref = Process.monitor(pid)
      state = put_in(state.viewers[pid], ref)
      {:noreply, maybe_attach(state)}
    end
  end

  def handle_cast({:set_filter, filter}, state) do
    filter = Map.merge(state.filter, normalize_filter(filter))
    state = %{state | filter: filter}

    if state.attached? do
      :logger.set_handler_config(LogStreamHandler.handler_id(), :level, filter.level)
      :logger.update_handler_config(LogStreamHandler.handler_id(), :config, filter)
    end

    Phoenix.PubSub.broadcast(
      Bonfire.Common.PubSub,
      LogStreamHandler.topic(),
      {:log_filter_changed, filter}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = %{state | viewers: Map.delete(state.viewers, pid)}
    {:noreply, maybe_detach(state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # attach the handler once there is at least one viewer (and streaming is enabled)
  defp maybe_attach(%{attached?: false} = state) do
    if enabled?() and map_size(state.viewers) > 0 do
      :logger.add_handler(LogStreamHandler.handler_id(), LogStreamHandler, %{
        level: state.filter.level,
        config: state.filter
      })

      %{state | attached?: true}
    else
      state
    end
  end

  defp maybe_attach(state), do: state

  # detach once the last viewer leaves
  defp maybe_detach(%{attached?: true} = state) do
    if map_size(state.viewers) == 0 do
      :logger.remove_handler(LogStreamHandler.handler_id())
      %{state | attached?: false}
    else
      state
    end
  end

  defp maybe_detach(state), do: state

  defp normalize_filter(filter) do
    filter
    |> Map.take([:level, :query, :modules])
    |> Map.update(:level, nil, &normalize_level/1)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp normalize_level(level) when is_atom(level), do: level

  defp normalize_level(level) when is_binary(level) do
    String.to_existing_atom(level)
  rescue
    ArgumentError -> :info
  end

  defp normalize_level(_), do: :info
end
