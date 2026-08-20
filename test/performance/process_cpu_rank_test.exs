defmodule Bonfire.UI.Common.ProcessCpuRankTest do
  @moduledoc """
  The ranking is the whole of the per-process CPU page: everything else is `live_table` rendering.

  It works on two `%{pid => reductions}` samples rather than on live processes, so the interesting cases (a process that appeared mid-window, one that died, or a window too short to mean anything) are all deterministic here rather than a race against real scheduling.
  """

  use ExUnit.Case, async: true

  @moduletag :ui

  alias Bonfire.UI.Common.ProcessCpuDashboardPage, as: Page

  # stand-ins for pids: the ranking never calls into them, it only uses them as keys
  defp p(n), do: :"process_#{n}"

  describe "rank_by_reductions/3" do
    test "ranks by work done in the window, not by lifetime total" do
      # b has burned far more reductions overall, but a did all the work *during* the window
      before = %{p(1) => 100, p(2) => 1_000_000}
      now = %{p(1) => 900, p(2) => 1_000_100}

      assert [%{key: first}, %{key: second}] = Page.rank_by_reductions(before, now, 10)
      assert first == p(1)
      assert second == p(2)
    end

    test "percentages are a share of the window's work and sum to ~100" do
      before = %{p(1) => 0, p(2) => 0, p(3) => 0}
      now = %{p(1) => 50, p(2) => 30, p(3) => 20}

      rows = Page.rank_by_reductions(before, now, 10)

      assert Enum.map(rows, & &1.percent) == [50.0, 30.0, 20.0]
      assert rows |> Enum.map(& &1.percent) |> Enum.sum() |> Float.round(1) == 100.0
    end

    test "counts a process that appeared mid-window from zero" do
      # no baseline, so all of its reductions were earned inside the window
      before = %{p(1) => 100}
      now = %{p(1) => 150, p(2) => 500}

      assert [%{key: top, reductions: 500} | _] = Page.rank_by_reductions(before, now, 10)
      assert top == p(2)
    end

    test "drops a process that went away" do
      before = %{p(1) => 100, p(2) => 100}
      now = %{p(1) => 200}

      assert [%{key: only}] = Page.rank_by_reductions(before, now, 10)
      assert only == p(1)
    end

    test "takes only the top n" do
      before = %{}
      now = for i <- 1..10, into: %{}, do: {p(i), i * 10}

      assert length(Page.rank_by_reductions(before, now, 3)) == 3
    end

    test "tolerates an idle window without dividing by zero" do
      sample = %{p(1) => 100, p(2) => 200}

      assert Enum.all?(Page.rank_by_reductions(sample, sample, 10), &(&1.percent == 0.0))
    end
  end

  describe "annotate/3" do
    # share of work answers "who did the most", but not "was that a lot" — an idle VM still has
    # someone at the top. The cpu factor scales it to % of one core, the top/htop convention:
    # normal_utilisation / 100 * cores, so a process alone on one core of ten reads ~100%.
    defp ranked(key, percent), do: %{key: key, percent: percent, reductions: 1}

    test "scales share of work into a percentage of one core" do
      # 50% of the work, schedulers 0.42% busy across 10 cores -> factor 0.042
      assert [%{cpu_percent: 2.1}] = Page.annotate([ranked(p(1), 50.0)], %{}, 0.042)
    end

    test "reads ~100% for a process with a core to itself" do
      # all the work, schedulers 10% busy across 10 cores -> one full core
      assert [%{cpu_percent: 100.0}] = Page.annotate([ranked(p(1), 100.0)], %{}, 1.0)
    end

    test "leaves CPU% unknown when utilisation is not yet known" do
      # the first window after mount has no earlier scheduler sample to diff against
      assert [%{cpu_percent: nil}] = Page.annotate([ranked(p(1), 50.0)], %{}, nil)
    end

    test "carries the aggregate CPU% for the same process" do
      assert [%{cpu_percent: last, aggregate_cpu_percent: aggregate}] =
               Page.annotate([ranked(p(1), 50.0)], %{p(1) => 20.0}, 1.0)

      assert last == 50.0
      assert aggregate == 20.0
    end

    test "has no aggregate for a process seen for the first time" do
      assert [%{aggregate_cpu_percent: nil}] =
               Page.annotate([ranked(p(1), 50.0)], %{p(2) => 10.0}, 1.0)
    end
  end

  defmodule NamedFixture do
    @moduledoc "A plain GenServer: `Process.info(:initial_call)` reports proc_lib for these, and the real MFA is only in the process dictionary."
    use GenServer

    def start, do: GenServer.start(__MODULE__, :ok)

    @impl GenServer
    def init(:ok), do: {:ok, :ok}
  end

  describe "naming" do
    test "uses the real initial call rather than proc_lib's wrapper" do
      # every OTP process reports {:proc_lib, :init_p, 5} as its initial_call, so reading only that
      # renders a whole prod table as ":proc_lib.init_p/5" and identifies nothing
      {:ok, pid} = NamedFixture.start()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      params = %{limit: 5_000, sort_by: :reductions, sort_dir: :desc}

      stale = %{
        Page.initial_state()
        | at: System.monotonic_time(:millisecond) - 10_000,
          sample: %{}
      }

      {rows, _total, _state} = Page.fetch_processes(params, node(), stale)
      row = Enum.find(rows, &(&1.key == pid))

      assert row, "the fixture process should appear in the table"
      refute row.name =~ "proc_lib"
      assert row.name =~ "NamedFixture"
    end

    test "prefers a registered name when there is one" do
      row =
        %{key: Process.whereis(:code_server), percent: 0.0, reductions: 1}
        |> List.wrap()
        |> Page.describe_rows()
        |> hd()

      assert row.name =~ "code_server"
    end
  end

  describe "fetch_processes/3" do
    @params %{limit: 50, sort_by: :percent, sort_dir: :desc}

    defp row(key), do: %{key: key, percent: 50.0, reductions: 5, message_queue_len: 0}

    # built from initial_state/0 rather than by hand, so these can't drift from the real shape
    defp state_at(at, rows), do: %{Page.initial_state() | sample: %{}, at: at, rows: rows}

    test "reuses the last ranking within the window, so re-sorting can't scramble the numbers" do
      # live_table re-runs the fetcher on every sort/limit/search change, not only on refresh
      rows = [row(:a)]
      state = state_at(System.monotonic_time(:millisecond), rows)

      assert {^rows, 1, ^state} = Page.fetch_processes(@params, node(), state)
    end

    test "takes a fresh sample once the window has passed" do
      stale_at = System.monotonic_time(:millisecond) - 10_000
      state = state_at(stale_at, [row(:a)])

      assert {rows, total, new_state} = Page.fetch_processes(@params, node(), state)

      assert new_state.at > stale_at
      # a real sample of this VM, so it has to have found the test process at least
      assert map_size(new_state.sample) > 0
      assert total > 0
      assert length(rows) <= @params.limit
    end
  end
end
