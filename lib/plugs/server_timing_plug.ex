defmodule Bonfire.UI.Common.ServerTimingPlug do
  @moduledoc """
  A Plug that adds Server-Timing headers to HTTP responses.

  This enables detailed server-side timing information to be visible in browser
  DevTools under the "Timing" tab, helping identify performance bottlenecks.

  ## Metrics Tracked

  - `total` - Total request processing time
  - `db` - Cumulative database query time
  - `db_count` - Number of database queries executed
  - `queue` - Time spent waiting in the connection queue

  ## Usage

  Add to your endpoint before the router:

      plug Bonfire.UI.Common.ServerTimingPlug

  Then open browser DevTools → Network → select a request → Timing tab
  to see the Server Timing section populated with these metrics.

  ## Security Considerations

  Server-Timing headers may expose internal timing information. Consider:
  - Only enabling in development/staging environments
  - Using the `:enabled` option to conditionally enable based on user/request

  ## Options

  - `:enabled` - Function that receives conn and returns boolean (default: always enabled)
  - `:include_descriptions` - Whether to include human-readable descriptions (default: true)

  ## Example Output

  ```
  Server-Timing: db;dur=53.2;desc="Database", db_count;dur=5;desc="Query Count", total;dur=304.5;desc="Total"
  ```
  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  # Process dictionary keys for accumulating metrics
  @timing_start_key :server_timing_start
  @db_time_key :server_timing_db_time
  @db_count_key :server_timing_db_count
  @queue_time_key :server_timing_queue_time

  @impl true
  def init(opts) do
    %{
      enabled: Keyword.get(opts, :enabled, fn _conn -> true end),
      include_descriptions: Keyword.get(opts, :include_descriptions, true)
    }
  end

  @impl true
  def call(conn, opts) do
    if should_enable?(conn, opts) do
      start_timing(conn, opts)
    else
      conn
    end
  end

  defp should_enable?(conn, %{enabled: enabled_fn}) when is_function(enabled_fn, 1) do
    enabled_fn.(conn)
  end

  defp should_enable?(_conn, %{enabled: enabled}) when is_boolean(enabled), do: enabled
  defp should_enable?(_conn, _opts), do: true

  defp start_timing(conn, opts) do
    start_time = System.monotonic_time(:microsecond)

    # Initialize process dictionary for this request
    Process.put(@timing_start_key, start_time)
    Process.put(@db_time_key, 0)
    Process.put(@db_count_key, 0)
    Process.put(@queue_time_key, 0)

    register_before_send(conn, fn conn ->
      add_server_timing_header(conn, opts)
    end)
  end

  defp add_server_timing_header(conn, opts) do
    start_time = Process.get(@timing_start_key)

    if start_time do
      total_time = System.monotonic_time(:microsecond) - start_time
      db_time = Process.get(@db_time_key, 0)
      db_count = Process.get(@db_count_key, 0)
      queue_time = Process.get(@queue_time_key, 0)

      # Calculate app time (total - db - queue)
      app_time = max(0, total_time - db_time - queue_time)

      timing_header = build_timing_header(
        %{
          total: total_time,
          db: db_time,
          db_count: db_count,
          queue: queue_time,
          app: app_time
        },
        opts
      )

      # Clean up process dictionary
      cleanup_process_dict()

      put_resp_header(conn, "server-timing", timing_header)
    else
      conn
    end
  end

  defp build_timing_header(metrics, opts) do
    include_desc = Map.get(opts, :include_descriptions, true)

    [
      format_metric("db", metrics.db, "Database", include_desc),
      format_metric("db_count", metrics.db_count, "Queries", include_desc, :count),
      format_metric("queue", metrics.queue, "Queue", include_desc),
      format_metric("app", metrics.app, "App", include_desc),
      format_metric("total", metrics.total, "Total", include_desc)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp format_metric(name, value, desc, include_desc, type \\ :duration)

  # Skip metrics with zero or negative values (except counts)
  defp format_metric(_name, value, _desc, _include_desc, :duration) when value <= 0, do: nil

  defp format_metric(name, value, desc, include_desc, :duration) do
    # Convert microseconds to milliseconds with 2 decimal places
    ms = Float.round(value / 1000, 2)

    if include_desc do
      "#{name};dur=#{ms};desc=\"#{desc}\""
    else
      "#{name};dur=#{ms}"
    end
  end

  defp format_metric(name, value, desc, include_desc, :count) do
    if include_desc do
      "#{name};dur=#{value};desc=\"#{desc}\""
    else
      "#{name};dur=#{value}"
    end
  end

  defp cleanup_process_dict do
    Process.delete(@timing_start_key)
    Process.delete(@db_time_key)
    Process.delete(@db_count_key)
    Process.delete(@queue_time_key)
  end

  # Public API for recording metrics from telemetry handlers

  @doc """
  Records database query time. Called by the telemetry handler.

  ## Parameters
  - `query_time` - Query execution time in microseconds
  - `queue_time` - Time spent in connection queue in microseconds (optional)
  """
  def record_db_query(query_time, queue_time \\ 0) do
    if Process.get(@timing_start_key) do
      current_db = Process.get(@db_time_key, 0)
      current_count = Process.get(@db_count_key, 0)
      current_queue = Process.get(@queue_time_key, 0)

      Process.put(@db_time_key, current_db + query_time)
      Process.put(@db_count_key, current_count + 1)
      Process.put(@queue_time_key, current_queue + queue_time)
    end
  end

  @doc """
  Records a custom timing metric.

  ## Parameters
  - `key` - Atom key for the metric (will be added to process dictionary)
  - `duration` - Duration in microseconds
  """
  def record_custom(key, duration) when is_atom(key) and is_number(duration) do
    if Process.get(@timing_start_key) do
      Process.put({:server_timing_custom, key}, duration)
    end
  end
end
