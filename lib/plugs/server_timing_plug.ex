defmodule Bonfire.UI.Common.ServerTimingPlug do
  @moduledoc """
  Plug that adds Server-Timing headers to HTTP responses and records to the profiler dashboard.

  Enabled when `PAGE_PROFILER_ENABLED=true`. Metrics are visible in browser
  DevTools (Network → Timing tab) and in `/admin/system/page_profiler`.

  Tracks: plug pipeline, router overhead, DB queries, LV mount/handle_params,
  and dead render time (computed as total minus tracked phases).
  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  alias Bonfire.UI.Common.PageTimingStorage

  @timing_start_key :server_timing_start
  @db_time_key :server_timing_db_time
  @db_count_key :server_timing_db_count
  @queue_time_key :server_timing_queue_time

  @impl true
  def init(opts) do
    %{
      enabled: Keyword.get(opts, :enabled, :default),
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

  defp should_enable?(_conn, _opts), do: PageTimingStorage.enabled?()

  defp start_timing(conn, opts) do
    start_time = System.monotonic_time(:microsecond)

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

      lv_mount_disconnected = Process.get({:server_timing_custom, :lv_mount_disconnected})
      lv_handle_params = Process.get({:server_timing_custom, :lv_handle_params})
      plugs_time = Process.get({:server_timing_custom, :plugs})
      router_time = Process.get({:server_timing_custom, :router})

      marker_before_parsers = Process.get({:server_timing_marker, :before_parsers})
      marker_after_parsers = Process.get({:server_timing_marker, :after_parsers})
      marker_before_session = Process.get({:server_timing_marker, :before_session})
      marker_after_session = Process.get({:server_timing_marker, :after_session})

      plug_parsers =
        if marker_before_parsers && marker_after_parsers,
          do: marker_after_parsers - marker_before_parsers

      plug_session =
        if marker_before_session && marker_after_session,
          do: marker_after_session - marker_before_session

      # LV mount/handle_params are wall-clock (include DB time), so don't subtract db/queue separately
      tracked_time =
        if lv_mount_disconnected || lv_handle_params do
          (plugs_time || 0) + (router_time || 0) +
            (lv_mount_disconnected || 0) + (lv_handle_params || 0)
        else
          (plugs_time || 0) + db_time + queue_time
        end

      app_time = max(0, total_time - tracked_time)
      # Dead render has no telemetry event; for LV pages it's the untracked remainder
      lv_render = if lv_mount_disconnected || lv_handle_params, do: app_time

      resp_size_kb =
        if conn.resp_body,
          do: Float.round(IO.iodata_length(conn.resp_body) / 1024, 1),
          else: 0.0

      all_custom_metrics = collect_all_custom_metrics()

      metrics =
        Map.merge(all_custom_metrics, %{
          resp_size_kb: resp_size_kb,
          total: total_time,
          db: db_time,
          db_count: db_count,
          queue: queue_time,
          plugs: plugs_time,
          plug_parsers: plug_parsers,
          plug_session: plug_session,
          router: router_time,
          app: app_time,
          lv_render: lv_render,
          lv_mount_disconnected: lv_mount_disconnected,
          lv_handle_params: lv_handle_params
        })

      timing_header = build_timing_header(metrics, opts)

      maybe_record_to_storage(conn, metrics)
      cleanup_process_dict()

      put_resp_header(conn, "server-timing", timing_header)
    else
      conn
    end
  end

  defp build_timing_header(metrics, opts) do
    include_desc = Map.get(opts, :include_descriptions, true)

    [
      format_metric("plug_parsers", metrics.plug_parsers, "Parsers", include_desc),
      format_metric("plug_session", metrics.plug_session, "Session", include_desc),
      format_metric("plugs", metrics.plugs, "Plugs", include_desc),
      format_metric("router", metrics.router, "Router", include_desc),
      format_metric("db", metrics.db, "Database", include_desc),
      format_metric("db_count", metrics.db_count, "Queries", include_desc, :count),
      format_metric("queue", metrics.queue, "Queue", include_desc),
      format_metric("lv_mount", metrics.lv_mount_disconnected, "Mount", include_desc),
      format_metric("lv_params", metrics.lv_handle_params, "Params", include_desc),
      format_metric("lv_render", metrics.lv_render, "Render", include_desc),
      format_metric("total", metrics.total, "Total", include_desc)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp format_metric(name, value, desc, include_desc, type \\ :duration)

  defp format_metric(_name, nil, _desc, _include_desc, _type), do: nil
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

  defp collect_all_custom_metrics do
    Process.get()
    |> Enum.filter(fn
      {{:server_timing_custom, _key}, _value} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:server_timing_custom, key}, value} -> {key, value} end)
    |> Map.new()
  end

  defp cleanup_process_dict do
    Process.delete(@timing_start_key)
    Process.delete(@db_time_key)
    Process.delete(@db_count_key)
    Process.delete(@queue_time_key)

    Process.get()
    |> Enum.each(fn
      {{:server_timing_custom, _key}, _value} = item ->
        Process.delete(elem(item, 0))

      {{:server_timing_marker, _key}, _value} = item ->
        Process.delete(elem(item, 0))

      _ ->
        :ok
    end)
  end

  defp maybe_record_to_storage(conn, metrics) do
    if PageTimingStorage.enabled?() and not excluded_path?(conn.request_path) do
      request_id =
        conn.assigns[:request_id] ||
          get_req_header(conn, "x-request-id") |> List.first() ||
          generate_request_id()

      PageTimingStorage.record_request(%{
        request_id: request_id,
        path: conn.request_path,
        method: conn.method,
        status: conn.status,
        timestamp: DateTime.utc_now(),
        timings: metrics
      })
    end
  rescue
    _ -> :ok
  end

  @excluded_prefixes ["/admin/system", "/assets/", "/images/", "/fonts/", "/live/"]

  defp excluded_path?(path) do
    Enum.any?(@excluded_prefixes, &String.starts_with?(path, &1))
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  @doc "Accumulates DB query time and count. Called by the Ecto telemetry handler."
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

  @doc "Records a custom timing metric (atom key, microseconds). Overwrites if key exists."
  def record_custom(key, duration) when is_atom(key) and is_number(duration) do
    if Process.get(@timing_start_key) do
      Process.put({:server_timing_custom, key}, duration)
    end
  end

  @doc "Accumulates a custom timing metric (atom key, microseconds). Adds to any existing value."
  def accumulate_custom(key, duration) when is_atom(key) and is_number(duration) do
    if Process.get(@timing_start_key) do
      current = Process.get({:server_timing_custom, key}, 0)
      Process.put({:server_timing_custom, key}, current + duration)
    end
  end
end
