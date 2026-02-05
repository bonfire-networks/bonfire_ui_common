defmodule Bonfire.UI.Common.PageTimingTelemetry do
  @moduledoc """
  Telemetry handler for capturing LiveView lifecycle events.

  Attaches to Phoenix LiveView telemetry events and records timing data
  to the process dictionary (for correlation with HTTP request) or directly
  to PageTimingStorage for WebSocket events.

  ## Events Captured

  - `[:phoenix, :live_view, :mount, :stop]` - LiveView mount (disconnected and connected)
  - `[:phoenix, :live_view, :handle_params, :stop]` - URL parameter handling

  ## Usage

  Called during application startup:

      Bonfire.UI.Common.PageTimingTelemetry.setup()
  """

  require Logger
  alias Bonfire.UI.Common.PageTimingStorage
  alias Bonfire.UI.Common.ServerTimingPlug

  @handler_id "bonfire-page-timing-liveview"

  @doc "Attach telemetry handlers for LiveView and router events"
  def setup do
    events = [
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

    Logger.debug("[PageTimingTelemetry] Attached LiveView and router event handlers")
    :ok
  end

  @doc "Detach telemetry handlers"
  def detach do
    :telemetry.detach(@handler_id)
  end

  @doc false
  def handle_event([:phoenix, :live_view, :mount, :stop], measurements, metadata, _config) do
    if PageTimingStorage.enabled?() do
      handle_mount(measurements, metadata)
    end
  end

  def handle_event([:phoenix, :live_view, :handle_params, :stop], measurements, metadata, _config) do
    if PageTimingStorage.enabled?() do
      handle_params(measurements, metadata)
    end
  end

  def handle_event([:phoenix, :router_dispatch, :start], _measurements, _metadata, _config) do
    if PageTimingStorage.enabled?() do
      handle_router_dispatch_start()
    end
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  # Private handlers

  defp handle_mount(measurements, metadata) do
    duration = get_duration(measurements)
    socket = Map.get(metadata, :socket)
    connected? = socket && function_exported?(Phoenix.LiveView, :connected?, 1) && Phoenix.LiveView.connected?(socket)

    key = if connected?, do: :lv_mount_connected, else: :lv_mount_disconnected

    # For disconnected mount, record to process dictionary (same process as HTTP request)
    # For connected mount, we're in a different process (WebSocket), so we record directly
    if connected? do
      # Connected mount happens in WebSocket process - record as separate event
      # We could track this separately, but for now we just record to process dict
      # in case there's a parent process tracking
      ServerTimingPlug.record_custom(key, duration)
    else
      # Disconnected mount - same process as HTTP request
      ServerTimingPlug.record_custom(key, duration)
    end
  rescue
    e ->
      Logger.debug("[PageTimingTelemetry] Error in handle_mount: #{inspect(e)}")
  end

  defp handle_params(measurements, metadata) do
    duration = get_duration(measurements)
    socket = Map.get(metadata, :socket)
    connected? = socket && function_exported?(Phoenix.LiveView, :connected?, 1) && Phoenix.LiveView.connected?(socket)

    # Only track disconnected handle_params (part of initial page load)
    unless connected? do
      ServerTimingPlug.record_custom(:lv_handle_params, duration)
    end
  rescue
    e ->
      Logger.debug("[PageTimingTelemetry] Error in handle_params: #{inspect(e)}")
  end

  defp handle_router_dispatch_start do
    # Get the request start time from process dictionary (set by ServerTimingPlug)
    start_time = Process.get(:server_timing_start)

    if start_time do
      # Calculate time spent in plug pipeline before routing
      plugs_time = System.monotonic_time(:microsecond) - start_time
      ServerTimingPlug.record_custom(:plugs, plugs_time)
    end
  rescue
    e ->
      Logger.debug("[PageTimingTelemetry] Error in handle_router_dispatch_start: #{inspect(e)}")
  end

  defp get_duration(%{duration: duration}) do
    System.convert_time_unit(duration, :native, :microsecond)
  end

  defp get_duration(_), do: 0
end
