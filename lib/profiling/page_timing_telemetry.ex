defmodule Bonfire.UI.Common.PageTimingTelemetry do
  @moduledoc """
  Telemetry handler for LiveView and router events. Records timing to the
  process dictionary for correlation with the HTTP request in `ServerTimingPlug`.

  Captures: router dispatch start (plugs metric), mount start (router overhead),
  mount stop (disconnected only), and handle_params stop (disconnected only).

  Called during application startup via `setup/0`.
  """

  alias Bonfire.UI.Common.ServerTimingPlug

  @handler_id "bonfire-page-timing-liveview"

  def setup do
    events = [
      [:phoenix, :live_view, :mount, :start],
      [:phoenix, :live_view, :mount, :stop],
      [:phoenix, :live_view, :handle_params, :stop],
      [:phoenix, :router_dispatch, :start]
    ]

    :telemetry.attach_many(
      @handler_id,
      events,
      &__MODULE__.handle_event/4,
      %{}
    )

    :ok
  end

  def detach do
    :telemetry.detach(@handler_id)
  end

  @doc false
  def handle_event(event, measurements, metadata, _config) do
    # Only record in the HTTP request process (where ServerTimingPlug set :server_timing_start)
    if Process.get(:server_timing_start), do: do_handle(event, measurements, metadata)
  end

  defp do_handle([:phoenix, :live_view, :mount, :start], _, _), do: handle_mount_start()
  defp do_handle([:phoenix, :live_view, :mount, :stop], m, meta), do: handle_mount(m, meta)

  defp do_handle([:phoenix, :live_view, :handle_params, :stop], m, meta),
    do: handle_params(m, meta)

  defp do_handle([:phoenix, :router_dispatch, :start], _, _), do: handle_router_dispatch_start()
  defp do_handle(_, _, _), do: :ok

  defp handle_mount(measurements, metadata) do
    duration = get_duration(measurements)
    socket = Map.get(metadata, :socket)

    unless socket && Phoenix.LiveView.connected?(socket) do
      ServerTimingPlug.record_custom(:lv_mount_disconnected, duration)
    end
  rescue
    _ -> :ok
  end

  defp handle_params(measurements, metadata) do
    duration = get_duration(measurements)
    socket = Map.get(metadata, :socket)

    unless socket && Phoenix.LiveView.connected?(socket) do
      ServerTimingPlug.record_custom(:lv_handle_params, duration)
    end
  rescue
    _ -> :ok
  end

  defp handle_mount_start do
    case Process.get({:server_timing_marker, :router_dispatch_start}) do
      nil ->
        :ok

      dispatch_time ->
        ServerTimingPlug.record_custom(
          :router,
          System.monotonic_time(:microsecond) - dispatch_time
        )
    end
  rescue
    _ -> :ok
  end

  defp handle_router_dispatch_start do
    start_time = Process.get(:server_timing_start)

    if start_time do
      now = System.monotonic_time(:microsecond)
      ServerTimingPlug.record_custom(:plugs, now - start_time)
      Process.put({:server_timing_marker, :router_dispatch_start}, now)
    end
  rescue
    _ -> :ok
  end

  defp get_duration(%{duration: duration}) do
    System.convert_time_unit(duration, :native, :microsecond)
  end

  defp get_duration(_), do: 0
end
