defmodule Bonfire.UI.Common.ServerTimingTelemetry do
  @moduledoc """
  Telemetry handlers for Server-Timing metrics collection.

  This module attaches to various telemetry events (Ecto queries, Phoenix,
  LiveView) and records timing data that gets included in Server-Timing
  HTTP headers by `Bonfire.UI.Common.ServerTimingPlug`.

  ## Setup

  Call `setup/1` during application startup, typically in your `Application.start/2`:

      def start(_type, _args) do
        Bonfire.UI.Common.ServerTimingTelemetry.setup(MyApp.Repo)
        # ... rest of supervision tree
      end

  Or integrate with the existing `Bonfire.Common.Telemetry.setup/2`:

      # In Bonfire.Common.Telemetry
      Bonfire.UI.Common.ServerTimingTelemetry.setup(repo_module)

  ## Metrics Collected

  - **Ecto queries**: Query time and queue time per database query
  - **LiveView mount/render**: (optional) Component rendering times
  """

  require Logger
  alias Bonfire.UI.Common.ServerTimingPlug

  @handler_id "bonfire-server-timing"

  @doc """
  Attaches telemetry handlers for server timing collection.

  ## Parameters
  - `repo_module` - The Ecto Repo module (e.g., `MyApp.Repo`)
  - `opts` - Options:
    - `:include_liveview` - Also track LiveView mount/render times (default: false)
  """
  def setup(repo_module, opts \\ []) when is_atom(repo_module) do
    # Get the telemetry prefix from repo config
    telemetry_prefix =
      if repo_module && function_exported?(repo_module, :config, 0) do
        repo_module.config()[:telemetry_prefix] || [:bonfire, :repo]
      else
        [:bonfire, :repo]
      end

    # Attach Ecto query handler
    :telemetry.attach(
      "#{@handler_id}-ecto",
      telemetry_prefix ++ [:query],
      &handle_ecto_query/4,
      %{}
    )

    if opts[:include_liveview] do
      setup_liveview_handlers()
    end

    Logger.info("Server-Timing telemetry handlers attached for #{inspect(telemetry_prefix)}")
    :ok
  rescue
    e ->
      Logger.warning("Failed to setup server timing telemetry: #{inspect(e)}")
      :error
  end

  @doc """
  Detaches all server timing telemetry handlers.
  """
  def detach do
    :telemetry.detach("#{@handler_id}-ecto")
    :telemetry.detach("#{@handler_id}-liveview")
    :ok
  rescue
    _ -> :ok
  end

  # Ecto query handler
  defp handle_ecto_query(
         _event,
         %{total_time: total_time, queue_time: queue_time} = _measurements,
         _metadata,
         _config
       ) do
    # Convert from native time units to microseconds
    query_time_us = System.convert_time_unit(total_time || 0, :native, :microsecond)
    queue_time_us = System.convert_time_unit(queue_time || 0, :native, :microsecond)

    ServerTimingPlug.record_db_query(query_time_us, queue_time_us)
  end

  defp handle_ecto_query(
         _event,
         %{query_time: query_time} = measurements,
         _metadata,
         _config
       ) do
    # Fallback for older Ecto versions or different measurement keys
    query_time_us = System.convert_time_unit(query_time || 0, :native, :microsecond)
    queue_time = Map.get(measurements, :queue_time, 0)
    queue_time_us = System.convert_time_unit(queue_time, :native, :microsecond)

    ServerTimingPlug.record_db_query(query_time_us, queue_time_us)
  end

  defp handle_ecto_query(_event, measurements, _metadata, _config) do
    # Handle any other measurement format gracefully
    Logger.debug("Unhandled Ecto telemetry measurements: #{inspect(measurements)}")
    :ok
  end

  # LiveView handlers (optional)
  defp setup_liveview_handlers do
    :telemetry.attach_many(
      "#{@handler_id}-liveview",
      [
        [:phoenix, :live_view, :mount, :stop],
        [:phoenix, :live_view, :handle_params, :stop],
        [:phoenix, :live_view, :handle_event, :stop],
        [:phoenix, :live_component, :handle_event, :stop]
      ],
      &handle_liveview_event/4,
      %{}
    )
  end

  defp handle_liveview_event(
         [:phoenix, :live_view, action, :stop],
         %{duration: duration},
         _metadata,
         _config
       ) do
    duration_us = System.convert_time_unit(duration, :native, :microsecond)
    ServerTimingPlug.record_custom(:"lv_#{action}", duration_us)
  end

  defp handle_liveview_event(
         [:phoenix, :live_component | _],
         %{duration: duration},
         _metadata,
         _config
       ) do
    duration_us = System.convert_time_unit(duration, :native, :microsecond)
    ServerTimingPlug.record_custom(:lv_component, duration_us)
  end

  defp handle_liveview_event(_event, _measurements, _metadata, _config), do: :ok
end
