defmodule Bonfire.UI.Common.ProcessCpuDashboardPage do
  @moduledoc """
  LiveDashboard page ranking processes by CPU work done in a window, at `/admin/system/process_cpu`.

  The built-in Processes page lists *cumulative* reductions, so a connection alive for hours shows millions whether it is busy now or has been idle all day. This samples twice and ranks by the difference, which is the closest the BEAM gets to a per-process CPU%: there is no such counter, but reductions are the unit of scheduled work.

  Sampling happens only while the page is mounted. The window is whatever "Update every" is set to, since `live_table`'s stateful `row_fetcher` carries the previous sample between refreshes.

  Message queue length is shown alongside, because reductions alone hide the opposite failure: a process blocked on IO burns almost none while still being slow.
  """

  use Phoenix.LiveDashboard.PageBuilder

  alias Bonfire.Common.Telemetry.Metrics

  # below this, a "window" is an artefact of re-sorting rather than elapsed time, and the
  # percentages would be noise
  @min_window_ms 1_000

  @impl true
  def menu_link(_, _) do
    {:ok, "Process CPU"}
  end

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, utilisation: nil, aggregate_utilisation: nil)}

  # the table's row_fetcher state is private to the table, so the page samples schedulers itself for
  # the summary line. Cheap: two counters, once per refresh, regardless of process count.
  # Two baselines, matching the two columns: the previous refresh, and the first one taken
  @impl true
  def handle_refresh(socket) do
    previous = socket.assigns[:scheduler_sample]
    baseline = socket.assigns[:baseline_schedulers]
    now = Metrics.scheduler_sample()

    {:noreply,
     assign(socket,
       scheduler_sample: now,
       baseline_schedulers: baseline || now,
       utilisation: previous && Metrics.scheduler_percentages(previous, now).normal,
       aggregate_utilisation: baseline && Metrics.scheduler_percentages(baseline, now).normal
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 1rem;">
      <p style="margin-bottom: 1rem; color: #495057;">
        Approximate CPU use per process, where <strong>100% is one core</strong>. Data collected over the whole time this page has been open and connected.
      </p>
      <p style="margin-bottom: 1rem; color: #495057;">
        Because the BEAM has no per-process CPU counter, this is reductions (scheduled work) scaled by how busy the schedulers were, unlike the Processes page which shows totals accumulated over each process's whole lifetime. Click a row for the full process info.
      </p>

      <.row :if={@utilisation}>
        <:col>
          <.card
            title="CPU in use, last"
            inner_title="of one core"
            hint="What the CPU % (last measure) column adds up to. Each row is one process's share of it."
          >
            {format_percent(total_cpu_percent(@utilisation))}
          </.card>
        </:col>
        <:col>
          <.card
            title="CPU in use, since opened"
            inner_title="of one core"
            hint="What the CPU % (since opened) column adds up to."
          >
            {format_percent(total_cpu_percent(@aggregate_utilisation))}
          </.card>
        </:col>
        <:col>
          <.card
            title="Schedulers busy, last"
            inner_title={"across #{Metrics.normal_scheduler_count()} cores"}
            hint="Scheduler utilisation over the same window as the CPU % (last measure) column, and what scales reductions into it."
          >
            {format_percent(@utilisation)}
          </.card>
        </:col>
      </.row>

      <.live_table
        id="process-cpu"
        dom_id="process-cpu-table"
        page={@page}
        title="Processes by work done"
        row_fetcher={{&fetch_processes/3, initial_state()}}
        row_attrs={&row_attrs/1}
        rows_name="processes"
        default_sort_by={:cpu_percent}
      >
        <:col
          :let={row}
          field={:aggregate_cpu_percent}
          sortable={:desc}
          header="CPU % (since opened)"
        >
          {format_percent(row.aggregate_cpu_percent)}
        </:col>
        <:col :let={row} field={:cpu_percent} sortable={:desc} header="CPU % (last measure)">
          <strong>{format_percent(row.cpu_percent)}</strong>
        </:col>
        <:col :let={row} field={:reductions} sortable={:desc} header="Reductions">
          {row.reductions}
        </:col>
        <:col :let={row} field={:name} header="Name or initial call">
          {row.name}
        </:col>
        <:col :let={row} field={:message_queue_len} sortable={:desc} header="MsgQ">
          {row.message_queue_len}
        </:col>
        <:col :let={row} field={:current_function} header="Current function">
          {row.current_function}
        </:col>
      </.live_table>
    </div>
    """
  end

  @doc false
  def initial_state,
    do: %{
      # rolling: the previous window
      sample: nil,
      scheduler_sample: nil,
      # fixed at mount, so the aggregate column spans the whole time the page has been open
      baseline: nil,
      baseline_schedulers: nil,
      at: nil,
      rows: [],
      utilisation: nil
    }

  @doc """
  Ranks two `%{key => reductions}` samples by the work done between them.

  Keys are pids in practice, but nothing here calls into them, which is what makes this testable without racing real processes.

  A process missing from `before` was spawned inside the window, so all of its reductions count. One missing from `now` has died and is dropped. An idle window yields zeroes rather than dividing by
  zero.
  """
  def rank_by_reductions(before, now, limit) do
    deltas =
      for {key, reductions} <- now do
        {key, reductions - Map.get(before, key, 0)}
      end

    total = Enum.reduce(deltas, 0, fn {_, delta}, acc -> acc + delta end)

    deltas
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {key, delta} ->
      %{key: key, reductions: delta, percent: percent(delta, total)}
    end)
  end

  defp percent(_delta, 0), do: 0.0
  defp percent(delta, total), do: Float.round(delta * 100 / total, 1)

  @doc """
  Turns share of work into a percentage of one core, and pairs it with the aggregate figure.

  `percent` is a share of whatever work happened, so it sums to 100 even on an idle VM. `cpu_factor` scales it to the `top`/`htop` convention where 100% is one core fully busy: `normal_utilisation / 100 * cores`. Scaling by raw utilisation instead would divide by the whole machine and leave every row rounding to `0.0%` on a quiet node.

  `nil` factor, as the first window, with no earlier scheduler sample, which leaves CPU% `nil` and renders as a dash rather than as a confident zero.

  `aggregate_cpu_percents` carries the same measure taken against the sample from when the page was opened. Reading the two columns against each other is the trend: rising means the process is busier now than it has been overall.
  """
  def annotate(rows, aggregate_cpu_percents, cpu_factor) do
    Enum.map(rows, fn %{key: key, percent: percent} = row ->
      Map.merge(row, %{
        cpu_percent: cpu_percent(percent, cpu_factor),
        aggregate_cpu_percent: Map.get(aggregate_cpu_percents, key)
      })
    end)
  end

  defp cpu_percent(_percent, nil), do: nil
  defp cpu_percent(percent, cpu_factor), do: Float.round(percent * cpu_factor, 2)

  @doc """
  `live_table`'s stateful row fetcher: samples, ranks against the previous sample, and carries the
  new one forward.

  It re-runs on sort, search and limit changes too, not only on refresh, so a fresh sample would often span milliseconds and the percentages would be noise. Within `#{@min_window_ms}ms` the last
  ranking is reused unchanged.
  """
  def fetch_processes(params, _node, %{at: at, rows: rows} = state)
      when is_integer(at) do
    if System.monotonic_time(:millisecond) - at < @min_window_ms do
      {limit_rows(rows, params), length(rows), state}
    else
      sample_and_rank(params, state)
    end
  end

  def fetch_processes(params, _node, state), do: sample_and_rank(params, state)

  defp sample_and_rank(params, %{sample: before, scheduler_sample: schedulers_before} = state) do
    now = sample()
    schedulers_now = Metrics.scheduler_sample()

    baseline = state.baseline || now
    baseline_schedulers = state.baseline_schedulers || schedulers_now

    utilisation = utilisation_between(schedulers_before, schedulers_now)

    # the same measure over the whole time the page has been open, so the two columns read as a trend
    aggregate =
      rank_by_reductions(baseline, now, 5_000)
      |> annotate(%{}, cpu_factor(utilisation_between(baseline_schedulers, schedulers_now)))
      |> Map.new(&{&1.key, &1.cpu_percent})

    rows =
      rank_by_reductions(before || %{}, now, 5_000)
      |> annotate(aggregate, cpu_factor(utilisation))
      |> Enum.map(&describe/1)

    state = %{
      state
      | sample: now,
        scheduler_sample: schedulers_now,
        baseline: baseline,
        baseline_schedulers: baseline_schedulers,
        at: System.monotonic_time(:millisecond),
        rows: rows,
        utilisation: utilisation
    }

    {limit_rows(rows, params), length(rows), state}
  end

  defp utilisation_between(nil, _now), do: nil
  defp utilisation_between(before, now), do: Metrics.scheduler_percentages(before, now).normal

  # to the top/htop convention, where 100% is one core rather than the whole machine
  defp cpu_factor(nil), do: nil
  defp cpu_factor(utilisation), do: utilisation / 100 * Metrics.normal_scheduler_count()

  defp limit_rows(rows, %{limit: limit, sort_by: sort_by, sort_dir: sort_dir}) do
    rows
    |> Enum.sort_by(&sort_key(&1, sort_by), sort_dir)
    |> Enum.take(limit)
  end

  # every sortable column is a number or nil, and nil sorts above numbers in term order, so an unknown CPU% would otherwise outrank a measured one in a highest-first sort
  defp sort_key(row, sort_by), do: Map.get(row, sort_by) || -1

  defp limit_rows(rows, _params), do: rows

  defp sample do
    for pid <- Process.list(),
        {:reductions, reductions} <- [Process.info(pid, :reductions)],
        into: %{},
        do: {pid, reductions}
  end

  # only for the rows actually shown, since Process.info/2 on every process would undo the point
  defp describe(%{key: pid} = row) do
    info =
      Process.info(pid, [:registered_name, :initial_call, :current_function, :message_queue_len])

    Map.merge(row, %{
      pid: inspect(pid),
      name: name_of(info),
      current_function: format_mfa(info[:current_function]),
      message_queue_len: info[:message_queue_len] || 0
    })
  end

  defp name_of(nil), do: "(exited)"

  defp name_of(info) do
    case info[:registered_name] do
      name when is_atom(name) and not is_nil(name) -> inspect(name)
      _ -> format_mfa(info[:initial_call])
    end
  end

  defp format_mfa({m, f, a}), do: "#{inspect(m)}.#{f}/#{a}"
  defp format_mfa(_), do: "-"

  @doc """
  Formats a CPU percentage, keeping small values legible.

  100% is one core. On a quiet node everything is genuinely a fraction of a percent, so rounding to
  one decimal would turn the whole column into `0.0%` and hide the ordering that is the point.
  """
  @doc """
  All CPU in use, in the same unit as the rows: percent of one core.

  Stated this way the header is a checksum rather than a second scale — the per-process figures sum
  to it, since each is that total apportioned by share of work. `busy × cores`, because "0.7% of ten
  cores" and "7% of one core" are the same quantity.
  """
  def total_cpu_percent(nil), do: nil
  def total_cpu_percent(utilisation), do: utilisation * Metrics.normal_scheduler_count()

  def format_percent(nil), do: "–"
  def format_percent(percent) when percent >= 1, do: "#{Float.round(percent, 1)}%"
  def format_percent(percent) when percent >= 0.01, do: "#{Float.round(percent, 2)}%"
  def format_percent(0.0), do: "0%"
  def format_percent(_percent), do: "<0.01%"

  # opens LiveDashboard's own process info modal, which links on to related processes and sockets.
  # `show_info` is handled by PageBuilder itself, so there is no event of ours behind this
  defp row_attrs(row) do
    [
      {"phx-click", "show_info"},
      {"phx-value-info", encode_pid(row.key)},
      {"phx-page-loading", true}
    ]
  end
end
