defmodule Bonfire.UI.Common.PageTimingStorage do
  @moduledoc """
  ETS-backed circular buffer for page timing data, displayed in the profiler dashboard.
  Configure via `PAGE_PROFILER_ENABLED=true` and `PAGE_PROFILER_MAX_ENTRIES=500` in `.env`.
  """

  use GenServer

  @table_name :page_timing_profiler
  @default_max_entries 500

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def enabled? do
    case Process.whereis(__MODULE__) do
      nil -> false
      _pid -> GenServer.call(__MODULE__, :enabled?)
    end
  catch
    :exit, _ -> false
  end

  def enable do
    GenServer.call(__MODULE__, :enable)
  catch
    :exit, _ -> {:error, :not_running}
  end

  def disable do
    GenServer.call(__MODULE__, :disable)
  catch
    :exit, _ -> {:error, :not_running}
  end

  def record_request(request_data) do
    GenServer.cast(__MODULE__, {:record, request_data})
  end

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

  def clear do
    GenServer.call(__MODULE__, :clear)
  catch
    :exit, _ -> {:error, :not_running}
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    app_config = Application.get_env(:bonfire_ui_common, __MODULE__, [])

    enabled = Keyword.get(opts, :enabled, Keyword.get(app_config, :enabled, false))

    max_entries =
      Keyword.get(opts, :max_entries, Keyword.get(app_config, :max_entries, @default_max_entries))

    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    {:ok,
     %{
       table: table,
       enabled: enabled,
       max_entries: max_entries,
       insertion_order: :queue.new()
     }}
  end

  @impl true
  def handle_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_call(:enable, _from, state) do
    {:reply, :ok, %{state | enabled: true}}
  end

  @impl true
  def handle_call(:disable, _from, state) do
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

  defp do_record(request_data, state) do
    request_id = request_data.request_id || generate_id()

    normalized = %{
      request_id: request_id,
      path: request_data.path,
      method: request_data.method,
      status: request_data.status,
      timestamp: request_data.timestamp || DateTime.utc_now(),
      timings: normalize_timings(request_data.timings)
    }

    :ets.insert(@table_name, {request_id, normalized})

    new_order = :queue.in(request_id, state.insertion_order)
    {new_order, state} = enforce_max_entries(new_order, state)

    %{state | insertion_order: new_order}
  end

  defp normalize_timings(timings) do
    timings
    |> Map.put_new(:total, 0)
    |> Map.put_new(:db, 0)
    |> Map.put_new(:db_count, 0)
    |> Map.put_new(:queue, 0)
    |> Map.put_new(:app, 0)
    |> Map.put(:remaining, calculate_remaining(timings))
  end

  defp calculate_remaining(timings) do
    total = Map.get(timings, :total, 0)
    plugs = Map.get(timings, :plugs, 0) || 0
    lv_mount = Map.get(timings, :lv_mount_disconnected, 0) || 0
    lv_handle_params = Map.get(timings, :lv_handle_params, 0) || 0

    if lv_mount > 0 || lv_handle_params > 0 do
      # For LV pages, the unaccounted time is the dead render (lv_render).
      # That's already stored as a separate metric, so remaining = 0 to avoid duplication.
      0
    else
      # For non-LV pages, remaining = total minus all tracked components
      db = Map.get(timings, :db, 0)
      queue = Map.get(timings, :queue, 0)
      max(0, total - plugs - db - queue)
    end
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
