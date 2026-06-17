defmodule Bonfire.UI.Common.LogStreamPage do
  @moduledoc """
  LiveDashboard page that streams `Logger` output in real time.

  Enable by running with `LIVE_DASHBOARD_LOGGER=true`, then visit `/admin/system/logs`. The `:logger` handler is attached only while this page is open (see `Bonfire.UI.Common.LogStreamManager`) and filters at the source — the search box / level select narrow what is captured for *new* lines. Use the browser's find (Cmd/Ctrl+F) to search lines already in the buffer.

  Rendering follows the upstream Request Logger page: rows are a LiveView **stream** (`phx-update="stream"`) so existing rows are never re-sent, capped via the stream `:limit` (selectable in the UI). Incoming events are coalesced on a short timer to keep DOM operations batched. Rows reuse LiveDashboard's own `log-level-*` / `logs-card` CSS, and Untangle's ANSI colors are converted to HTML via `AnsiToHTML`.
  """

  use Phoenix.LiveDashboard.PageBuilder

  alias Bonfire.UI.Common.LogStreamHandler
  alias Bonfire.UI.Common.LogStreamManager

  @default_limit 500
  @limit_options [100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000]
  @flush_interval 250
  @levels ~w(debug info warning error)a
  # convert Untangle's ANSI colors to HTML, wrapped in a bare <span> (not AnsiToHTML's default black <pre>)
  @ansi_theme %AnsiToHTML.Theme{name: "log-stream", container: {:span, []}}

  @impl true
  def menu_link(_, _) do
    {:ok, "App Logs"}
  end

  @impl true
  def mount(_params, _session, socket) do
    enabled = LogStreamManager.enabled?()

    if enabled and connected?(socket) do
      Phoenix.PubSub.subscribe(Bonfire.Common.PubSub, LogStreamHandler.topic())
      LogStreamManager.viewer_joined(self())
      Process.send_after(self(), :flush_logs, @flush_interval)
    end

    filter = if enabled, do: LogStreamManager.current_filter(), else: %{level: :info, query: nil}

    socket =
      socket
      |> assign(
        enabled: enabled,
        pending: [],
        paused: false,
        count: 0,
        limit: @default_limit,
        level: filter[:level] || :info,
        query: filter[:query] || ""
      )
      |> stream_configure(:messages, dom_id: & &1.id, limit: @default_limit)
      |> stream(:messages, [])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, levels: @levels, limit_options: @limit_options)

    ~H"""
    <style>
      .logs-card #logger-messages{background:#0b0f14}
      .logs-card #logger-messages pre{color:#cbd5e1}
      .logs-card #logger-messages pre:hover{background:rgba(255,255,255,.05)}
    </style>

    <div id="als" style="padding:1rem;">
      <h2 style="margin-bottom:1rem;font-size:1.5rem;font-weight:bold;">App Logs</h2>

      <%= if @enabled do %>
        <form
          phx-change="search"
          style="display:flex;gap:.5rem;margin-bottom:.75rem;flex-wrap:wrap;align-items:center;"
        >
          <input
            type="text"
            name="query"
            value={@query}
            placeholder="Filter new lines (substring)…"
            style="flex:1;min-width:200px;padding:.5rem .75rem;border-radius:6px;border:1px solid #d1d5db;font-size:.875rem;"
          />
          <select
            name="level"
            style="padding:.5rem;border-radius:6px;border:1px solid #d1d5db;font-size:.875rem;"
          >
            <option :for={level <- @levels} value={level} selected={@level == level}>
              <%= level %>+
            </option>
          </select>
        </form>

        <div style="display:flex;gap:.5rem;margin-bottom:1rem;flex-wrap:wrap;align-items:center;">
          <label style="color:#6b7280;font-size:.75rem;">Max lines</label>
          <form phx-change="set_limit" style="display:flex;align-items:center;gap:.25rem;">
            <select
              name="limit"
              style="padding:.5rem;border-radius:6px;border:1px solid #d1d5db;font-size:.875rem;"
            >
              <option :for={n <- @limit_options} value={n} selected={@limit == n}><%= n %></option>
            </select>
          </form>

          <button
            phx-click={if @paused, do: "resume", else: "pause"}
            style={"padding:.5rem 1rem;border-radius:6px;border:1px solid #d1d5db;cursor:pointer;font-size:.875rem;background:#{if @paused, do: "#f0fdf4", else: "#fef2f2"};color:#{if @paused, do: "#166534", else: "#991b1b"};"}
          >
            <%= if @paused, do: "Resume", else: "Pause" %>
          </button>
          <button
            phx-click="clear"
            style="padding:.5rem 1rem;border-radius:6px;border:1px solid #d1d5db;cursor:pointer;font-size:.875rem;background:#f9fafb;"
          >
            Clear
          </button>

          <span style="font-size:.75rem;color:#6b7280;">
            received: <%= @count %> · showing newest <%= @limit %> · filter applies to new logs only, use browser find (⌘/Ctrl+F) to search existing logs
          </span>
        </div>

        <%!-- `.logs-card` is `display:none` until `data-messages-present="true"`, and its inner
              `#logger-messages` is fixed at 350px — both overridden here (LiveDashboard CSS) --%>
        <div class="logs-card" data-messages-present={to_string(@count > 0)}>
          <div id="logger-messages" phx-update="stream" style="height:70vh">
            <pre
              :for={{id, m} <- @streams.messages}
              id={id}
              class={"log-level-#{m.level} text-wrap"}
            ><span style="color:#6b7280"><%= m.prefix %></span><%= m.html %></pre>
          </div>
        </div>
      <% else %>
        <div style="background:#fefce8;border-radius:8px;padding:2rem;border:1px solid #fde047;text-align:center;">
          <h3 style="font-size:1.125rem;font-weight:600;margin-bottom:.5rem;color:#854d0e;">
            Log Streaming Disabled
          </h3>
          <p style="color:#a16207;margin-bottom:1rem;">
            Live log streaming is currently disabled. Enable it to stream logs to this page.
          </p>
          <div style="font-family:ui-monospace,monospace;font-size:.875rem;background:#fff;padding:1rem;border-radius:6px;text-align:left;">
            <p style="margin-bottom:.5rem;"><strong>To enable, run with:</strong></p>
            <code style="display:block;background:#f3f4f6;padding:.5rem;border-radius:4px;">LIVE_DASHBOARD_LOGGER=true</code>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search", params, socket) do
    LogStreamManager.set_filter(%{
      query: Map.get(params, "query", ""),
      level: Map.get(params, "level", "info")
    })

    {:noreply, socket}
  end

  def handle_event("pause", _params, socket), do: {:noreply, assign(socket, paused: true)}
  def handle_event("resume", _params, socket), do: {:noreply, assign(socket, paused: false)}

  def handle_event("clear", _params, socket) do
    {:noreply, socket |> stream(:messages, [], reset: true) |> assign(pending: [], count: 0)}
  end

  def handle_event("set_limit", %{"limit" => limit}, socket) do
    # new cap takes effect on the next flush (stream/4 `:limit` trims on insert)
    {:noreply, assign(socket, limit: String.to_integer(limit))}
  end

  @impl true
  def handle_info({:log_event, event}, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      {:noreply, update(socket, :pending, &[to_row(event) | &1])}
    end
  end

  def handle_info({:log_filter_changed, filter}, socket) do
    {:noreply,
     assign(socket, level: filter[:level] || socket.assigns.level, query: filter[:query] || "")}
  end

  def handle_info(:flush_logs, socket) do
    Process.send_after(self(), :flush_logs, @flush_interval)

    case socket.assigns.pending do
      [] ->
        {:noreply, socket}

      # `pending` is newest-first; inserting at the top keeps newest rows on top
      rows ->
        {:noreply,
         socket
         |> stream(:messages, rows, at: 0, limit: socket.assigns.limit)
         |> assign(pending: [], count: socket.assigns.count + length(rows))}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # Build a render-ready row once, off the render path.
  defp to_row(event) do
    prefix =
      [format_time(event.time), short_module(event.module)]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("  ")
      |> case do
        "" -> ""
        p -> p <> "  "
      end

    %{
      id: "log-#{System.unique_integer([:monotonic, :positive])}",
      level: to_string(event.level),
      prefix: prefix,
      # ANSI colors → safe HTML (escapes text content)
      html:
        event.message |> drop_unsupported_ansi() |> AnsiToHTML.generate_phoenix_html(@ansi_theme)
    }
  end

  # AnsiToHTML 0.6 doesn't support "faint" (\e[2m / \e[22m), which Untangle uses for the
  # location suffix — strip it so the lib doesn't log a warning for every line (which would
  # then flood this very stream).
  defp drop_unsupported_ansi(message), do: String.replace(message, ~r/\x1b\[22?m/, "")

  defp short_module(nil), do: ""

  defp short_module(module) when is_atom(module),
    do: module |> Atom.to_string() |> String.replace_prefix("Elixir.", "")

  defp short_module(other), do: inspect(other)

  defp format_time(nil), do: ""

  # `:logger` meta[:time] is system time in microseconds
  defp format_time(micro) when is_integer(micro) do
    case DateTime.from_unix(micro, :microsecond) do
      {:ok, dt} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> ""
    end
  end

  defp format_time(_), do: ""
end
