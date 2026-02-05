defmodule Bonfire.UI.Common.PageTimingStorage do
  @moduledoc """
  GenServer with ETS storage for page load timing data.

  Stores recent request timing information for display in the LiveDashboard profiler page.
  Uses a circular buffer to limit memory usage.

  ## Configuration

  Set in `.env`:
  - `PAGE_PROFILER_ENABLED=true` - Enable profiling (disabled by default)
  - `PAGE_PROFILER_MAX_ENTRIES=500` - Max requests to store (default 500)

  ## Usage

      # Check if profiling is enabled
      PageTimingStorage.enabled?()

      # Record a request (called by ServerTimingPlug)
      PageTimingStorage.record_request(%{
        request_id: "abc123",
        path: "/feed",
        method: "GET",
        status: 200,
        timestamp: DateTime.utc_now(),
        timings: %{total: 150_000, db: 50_000, ...}
      })

      # Query stored requests
      PageTimingStorage.list_requests()
      PageTimingStorage.get_statistics()
  """

  use GenServer
  require Logger

  @table_name :page_timing_profiler
  @default_max_entries 500

  # Client API

  @doc "Start the storage GenServer"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Check if profiling is enabled"
  def enabled? do
    case Process.whereis(__MODULE__) do
      nil -> false
      _pid -> GenServer.call(__MODULE__, :enabled?)
    end
  catch
    :exit, _ -> false
  end

  @doc "Enable profiling at runtime"
  def enable do
    GenServer.call(__MODULE__, :enable)
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc "Disable profiling at runtime"
  def disable do
    GenServer.call(__MODULE__, :disable)
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc "Record a request timing profile"
  def record_request(request_data) do
    # Early return if not enabled - zero overhead path
    if enabled?() do
      GenServer.cast(__MODULE__, {:record, request_data})
    end
  end

  @doc "List recent requests with optional filters"
  def list_requests(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    path_filter = Keyword.get(opts, :path)

    try do
      @table_name
      |> :ets.tab2list()
      |> Enum.map(fn {_key, data} -> data end)
      |> maybe_filter_path(path_filter)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
      |> Enum.take(limit)
    rescue
      ArgumentError -> []
    end
  end

  @doc "Get a single request by ID"
  def get_request(request_id) do
    case :ets.lookup(@table_name, request_id) do
      [{^request_id, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  @doc "Get aggregated statistics"
  def get_statistics do
    requests = list_requests(limit: 1000)
    count = length(requests)

    if count == 0 do
      %{
        count: 0,
        avg_total: 0,
        avg_db: 0,
        avg_db_count: 0,
        p50_total: 0,
        p95_total: 0,
        p99_total: 0
      }
    else
      totals = Enum.map(requests, & &1.timings.total)
      db_times = Enum.map(requests, & &1.timings.db)
      db_counts = Enum.map(requests, & &1.timings.db_count)

      %{
        count: count,
        avg_total: avg(totals),
        avg_db: avg(db_times),
        avg_db_count: round(avg(db_counts)),
        p50_total: percentile(totals, 50),
        p95_total: percentile(totals, 95),
        p99_total: percentile(totals, 99)
      }
    end
  end

  @doc "Clear all stored data"
  def clear do
    GenServer.call(__MODULE__, :clear)
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc "Get current entry count"
  def count do
    try do
      :ets.info(@table_name, :size)
    rescue
      ArgumentError -> 0
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Read config from application env (set via runtime.exs from .env)
    app_config = Application.get_env(:bonfire_ui_common, __MODULE__, [])
    Logger.debug("[PageTimingStorage] init with opts=#{inspect(opts)}, app_config=#{inspect(app_config)}")

    enabled = Keyword.get(opts, :enabled, Keyword.get(app_config, :enabled, false))
    max_entries = Keyword.get(opts, :max_entries, Keyword.get(app_config, :max_entries, @default_max_entries))

    # Create ETS table for fast concurrent reads
    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    state = %{
      table: table,
      enabled: enabled,
      max_entries: max_entries,
      insertion_order: :queue.new()
    }

    Logger.info("[PageTimingStorage] Started with enabled=#{enabled}, max_entries=#{max_entries}")

    {:ok, state}
  end

  @impl true
  def handle_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_call(:enable, _from, state) do
    Logger.info("[PageTimingStorage] Profiling enabled")
    {:reply, :ok, %{state | enabled: true}}
  end

  @impl true
  def handle_call(:disable, _from, state) do
    Logger.info("[PageTimingStorage] Profiling disabled")
    {:reply, :ok, %{state | enabled: false}}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, %{state | insertion_order: :queue.new()}}
  end

  @impl true
  def handle_cast({:record, request_data}, state) do
    if state.enabled do
      {:noreply, do_record(request_data, state)}
    else
      {:noreply, state}
    end
  end

  # Private Functions

  defp do_record(request_data, state) do
    request_id = request_data.request_id || generate_id()

    # Normalize the data structure
    normalized = %{
      request_id: request_id,
      path: request_data.path,
      method: request_data.method,
      status: request_data.status,
      timestamp: request_data.timestamp || DateTime.utc_now(),
      timings: normalize_timings(request_data.timings),
      view: Map.get(request_data, :view)
    }

    # Insert into ETS
    :ets.insert(@table_name, {request_id, normalized})

    # Track insertion order for circular buffer
    new_order = :queue.in(request_id, state.insertion_order)

    # Enforce max entries (circular buffer)
    {new_order, state} = enforce_max_entries(new_order, state)

    %{state | insertion_order: new_order}
  end

  defp normalize_timings(timings) do
    %{
      total: Map.get(timings, :total, 0),
      db: Map.get(timings, :db, 0),
      db_count: Map.get(timings, :db_count, 0),
      queue: Map.get(timings, :queue, 0),
      plugs: Map.get(timings, :plugs),
      app: Map.get(timings, :app, 0),
      remaining: calculate_remaining(timings),
      lv_mount_disconnected: Map.get(timings, :lv_mount_disconnected),
      lv_mount_connected: Map.get(timings, :lv_mount_connected),
      lv_handle_params: Map.get(timings, :lv_handle_params)
    }
  end

  defp calculate_remaining(timings) do
    total = Map.get(timings, :total, 0)
    plugs = Map.get(timings, :plugs, 0) || 0
    db = Map.get(timings, :db, 0)
    queue = Map.get(timings, :queue, 0)
    lv_mount = Map.get(timings, :lv_mount_disconnected, 0) || 0
    lv_handle_params = Map.get(timings, :lv_handle_params, 0) || 0

    # remaining = total time minus all tracked components
    max(0, total - plugs - db - queue - lv_mount - lv_handle_params)
  end

  defp enforce_max_entries(order, state) do
    size = :queue.len(order)

    if size > state.max_entries do
      {{:value, oldest_id}, new_order} = :queue.out(order)
      :ets.delete(@table_name, oldest_id)
      enforce_max_entries(new_order, state)
    else
      {order, state}
    end
  end

  defp maybe_filter_path(requests, nil), do: requests
  defp maybe_filter_path(requests, pattern) do
    Enum.filter(requests, fn req -> String.contains?(req.path, pattern) end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp avg([]), do: 0
  defp avg(list), do: round(Enum.sum(list) / length(list))

  defp percentile([], _p), do: 0
  defp percentile(list, p) do
    sorted = Enum.sort(list)
    k = (length(sorted) - 1) * p / 100
    f = floor(k)
    c = ceil(k)

    if f == c do
      Enum.at(sorted, round(k))
    else
      lower = Enum.at(sorted, f)
      upper = Enum.at(sorted, c)
      round(lower + (upper - lower) * (k - f))
    end
  end
end
