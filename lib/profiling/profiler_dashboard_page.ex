defmodule Bonfire.UI.Common.ProfilerDashboardPage do
  @moduledoc """
  LiveDashboard page for profiling page load timing.

  Shows detailed timing breakdowns for HTTP requests including:
  - Plug pipeline time (before routing)
  - Database query time and count
  - Connection queue wait time
  - LiveView mount time (disconnected/connected)
  - LiveView handle_params time
  - Remaining time (total minus all tracked components)
  - Total request time

  ## Configuration

  Enable via `.env`:

      PAGE_PROFILER_ENABLED=true

  Then visit `/admin/system/page_profiler` to see the dashboard.
  """

  use Phoenix.LiveDashboard.PageBuilder

  alias Bonfire.UI.Common.PageTimingStorage

  @impl true
  def menu_link(_, _) do
    {:ok, "Page Profiler"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 1rem;">
      <h2 style="margin-bottom: 1rem; font-size: 1.5rem; font-weight: bold;">Page Load Profiler</h2>

      <%= if @enabled do %>
        <!-- Statistics Row -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1rem; margin-bottom: 1.5rem;">
          <div style="background: #f0fdf4; border-radius: 8px; padding: 1rem; border: 1px solid #86efac; text-align: center;">
            <div style="font-size: 1.5rem; font-weight: bold; color: #166534;"><%= @stats.count %></div>
            <div style="font-size: 0.875rem; color: #15803d;">Requests</div>
          </div>
          <div style="background: #eff6ff; border-radius: 8px; padding: 1rem; border: 1px solid #93c5fd; text-align: center;">
            <div style="font-size: 1.5rem; font-weight: bold; color: #1e40af;"><%= format_ms(@stats.avg_total) %></div>
            <div style="font-size: 0.875rem; color: #1d4ed8;">Avg Total</div>
          </div>
          <div style="background: #fefce8; border-radius: 8px; padding: 1rem; border: 1px solid #fde047; text-align: center;">
            <div style="font-size: 1.5rem; font-weight: bold; color: #854d0e;"><%= format_ms(@stats.p95_total) %></div>
            <div style="font-size: 0.875rem; color: #a16207;">P95 Total</div>
          </div>
          <div style="background: #fdf2f8; border-radius: 8px; padding: 1rem; border: 1px solid #f9a8d4; text-align: center;">
            <div style="font-size: 1.5rem; font-weight: bold; color: #9d174d;"><%= @stats.avg_db_count %></div>
            <div style="font-size: 0.875rem; color: #be185d;">Avg Queries</div>
          </div>
        </div>

        <!-- Controls -->
        <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap; align-items: center;">
          <button
            phx-click="toggle_profiling"
                        style={"padding: 0.5rem 1rem; border-radius: 6px; border: 1px solid #d1d5db; cursor: pointer; font-size: 0.875rem; background: #{if @enabled, do: "#fef2f2", else: "#f0fdf4"}; color: #{if @enabled, do: "#991b1b", else: "#166534"};"}
          >
            <%= if @enabled, do: "Disable Profiling", else: "Enable Profiling" %>
          </button>
          <button
            phx-click="clear_data"
                        style="padding: 0.5rem 1rem; border-radius: 6px; border: 1px solid #d1d5db; cursor: pointer; font-size: 0.875rem; background: #f9fafb;"
          >
            Clear Data
          </button>
          <button
            phx-click="refresh"
                        style="padding: 0.5rem 1rem; border-radius: 6px; border: 1px solid #d1d5db; cursor: pointer; font-size: 0.875rem; background: #f9fafb;"
          >
            Refresh
          </button>
        </div>

        <!-- Request Table -->
        <div style="background: #f8f9fa; border-radius: 8px; padding: 1rem; border: 1px solid #dee2e6;">
          <h3 style="font-size: 1rem; font-weight: 600; margin-bottom: 0.75rem; color: #495057;">Recent Requests</h3>
          <.live_table
            id="profiler-requests"
            dom_id="profiler-requests-table"
            page={@page}
            title=""
            row_fetcher={&fetch_requests/2}
            rows_name="requests"
          >
            <:col :let={req} field={:timestamp} sortable={:desc}>
              <%= format_timestamp(req.timestamp) %>
            </:col>
            <:col field={:method} />
            <:col :let={req} field={:path}>
              <span title={req.path}><%= truncate_path(req.path) %></span>
            </:col>
            <:col :let={req} field={:status}>
              <span style={"color: #{status_color(req.status)}"}><%= req.status %></span>
            </:col>
            <:col :let={req} field={:total} header="Total">
              <strong><%= format_ms(req.timings.total) %></strong>
            </:col>
            <:col :let={req} field={:db} header="DB">
              <%= format_ms(req.timings.db) %>
            </:col>
            <:col :let={req} field={:db_count} header="Qry">
              <%= req.timings.db_count %>
            </:col>
            <:col :let={req} field={:queue} header="Queue">
              <%= format_ms(req.timings.queue) %>
            </:col>
            <:col :let={req} field={:plugs} header="Plugs">
              <%= format_ms(req.timings.plugs) %>
            </:col>
            <:col :let={req} field={:remaining} header="Other">
              <%= format_ms(req.timings.remaining) %>
            </:col>
            <:col :let={req} field={:lv_mount} header="Mount">
              <%= format_ms(req.timings.lv_mount_disconnected) %>
            </:col>
            <:col :let={req} field={:lv_params} header="Params">
              <%= format_ms(req.timings.lv_handle_params) %>
            </:col>
            <:col :let={req} field={:breakdown} header="Breakdown">
              <%= render_timing_bar(req.timings) %>
            </:col>
          </.live_table>
        </div>

        <!-- Legend -->
        <div style="margin-top: 1rem; display: flex; gap: 1rem; flex-wrap: wrap; font-size: 0.75rem; color: #6b7280;">
          <span><span style="display: inline-block; width: 12px; height: 12px; background: #6366f1; border-radius: 2px; margin-right: 4px;"></span>Plugs</span>
          <span><span style="display: inline-block; width: 12px; height: 12px; background: #3b82f6; border-radius: 2px; margin-right: 4px;"></span>DB</span>
          <span><span style="display: inline-block; width: 12px; height: 12px; background: #f97316; border-radius: 2px; margin-right: 4px;"></span>Queue</span>
          <span><span style="display: inline-block; width: 12px; height: 12px; background: #8b5cf6; border-radius: 2px; margin-right: 4px;"></span>Mount</span>
          <span><span style="display: inline-block; width: 12px; height: 12px; background: #ec4899; border-radius: 2px; margin-right: 4px;"></span>Params</span>
          <span><span style="display: inline-block; width: 12px; height: 12px; background: #22c55e; border-radius: 2px; margin-right: 4px;"></span>Other</span>
        </div>
      <% else %>
        <!-- Disabled State -->
        <div style="background: #fefce8; border-radius: 8px; padding: 2rem; border: 1px solid #fde047; text-align: center;">
          <h3 style="font-size: 1.125rem; font-weight: 600; margin-bottom: 0.5rem; color: #854d0e;">Profiler Disabled</h3>
          <p style="color: #a16207; margin-bottom: 1rem;">
            Page load profiling is currently disabled. Enable it to see timing breakdowns.
          </p>
          <div style="font-family: ui-monospace, monospace; font-size: 0.875rem; background: #fff; padding: 1rem; border-radius: 6px; text-align: left; margin-bottom: 1rem;">
            <p style="margin-bottom: 0.5rem;"><strong>To enable via .env:</strong></p>
            <code style="display: block; background: #f3f4f6; padding: 0.5rem; border-radius: 4px;">
              PAGE_PROFILER_ENABLED=true
            </code>
            <p style="margin-top: 1rem; margin-bottom: 0.5rem;"><strong>Or enable at runtime:</strong></p>
          </div>
          <button
            phx-click="toggle_profiling"
                        style="padding: 0.75rem 1.5rem; border-radius: 6px; border: none; cursor: pointer; font-size: 0.875rem; background: #166534; color: white; font-weight: 500;"
          >
            Enable Profiling
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    enabled = PageTimingStorage.enabled?()
    stats = if enabled, do: PageTimingStorage.get_statistics(), else: default_stats()

    {:ok, assign(socket, enabled: enabled, stats: stats)}
  end

  @impl true
  def handle_event("toggle_profiling", _params, socket) do
    if socket.assigns.enabled do
      PageTimingStorage.disable()
    else
      PageTimingStorage.enable()
    end

    enabled = PageTimingStorage.enabled?()
    stats = if enabled, do: PageTimingStorage.get_statistics(), else: default_stats()

    {:noreply, assign(socket, enabled: enabled, stats: stats)}
  end

  @impl true
  def handle_event("clear_data", _params, socket) do
    PageTimingStorage.clear()
    stats = PageTimingStorage.get_statistics()
    {:noreply, assign(socket, stats: stats)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    stats = PageTimingStorage.get_statistics()
    {:noreply, assign(socket, stats: stats)}
  end

  # Data fetchers

  defp fetch_requests(_params, _node) do
    requests = PageTimingStorage.list_requests(limit: 100)
    {requests, length(requests)}
  end

  # Formatting helpers

  defp format_ms(nil), do: "-"
  defp format_ms(0), do: "-"
  defp format_ms(microseconds) when is_number(microseconds) do
    ms = microseconds / 1000
    cond do
      ms >= 1000 -> "#{Float.round(ms / 1000, 2)}s"
      ms >= 100 -> "#{round(ms)}ms"
      ms >= 1 -> "#{Float.round(ms, 1)}ms"
      true -> "<1ms"
    end
  end
  defp format_ms(_), do: "-"

  defp format_timestamp(nil), do: "-"
  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end
  defp format_timestamp(_), do: "-"

  defp truncate_path(path) when byte_size(path) > 40 do
    String.slice(path, 0, 37) <> "..."
  end
  defp truncate_path(path), do: path

  defp status_color(status) when status >= 500, do: "#dc2626"
  defp status_color(status) when status >= 400, do: "#f97316"
  defp status_color(status) when status >= 300, do: "#3b82f6"
  defp status_color(_status), do: "#22c55e"

  defp render_timing_bar(timings) do
    total = max(timings.total, 1)

    plugs_pct = safe_pct(timings.plugs, total)
    db_pct = safe_pct(timings.db, total)
    queue_pct = safe_pct(timings.queue, total)
    mount_pct = safe_pct(timings.lv_mount_disconnected, total)
    params_pct = safe_pct(timings.lv_handle_params, total)
    remaining_pct = safe_pct(timings.remaining, total)

    Phoenix.HTML.raw("""
    <div style="display: flex; height: 16px; width: 140px; border-radius: 4px; overflow: hidden; background: #e5e7eb;">
      <div style="width: #{plugs_pct}%; background: #6366f1;" title="Plugs: #{plugs_pct}%"></div>
      <div style="width: #{db_pct}%; background: #3b82f6;" title="DB: #{db_pct}%"></div>
      <div style="width: #{queue_pct}%; background: #f97316;" title="Queue: #{queue_pct}%"></div>
      <div style="width: #{mount_pct}%; background: #8b5cf6;" title="Mount: #{mount_pct}%"></div>
      <div style="width: #{params_pct}%; background: #ec4899;" title="Params: #{params_pct}%"></div>
      <div style="width: #{remaining_pct}%; background: #22c55e;" title="Other: #{remaining_pct}%"></div>
    </div>
    """)
  end

  defp safe_pct(nil, _total), do: 0
  defp safe_pct(value, total) when is_number(value) and total > 0 do
    round(value / total * 100)
  end
  defp safe_pct(_, _), do: 0

  defp default_stats do
    %{
      count: 0,
      avg_total: 0,
      avg_db: 0,
      avg_db_count: 0,
      p50_total: 0,
      p95_total: 0,
      p99_total: 0
    }
  end
end
