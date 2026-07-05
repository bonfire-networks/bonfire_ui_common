defmodule Bonfire.UI.Common.Timing do
  @moduledoc """
  Macros for instrumenting code blocks with Server-Timing metrics.

  When `PAGE_PROFILER_ENABLED` is not set at compile time, the macros compile
  to just the block — zero overhead in production.

  When enabled, records timing to the process dict via `ServerTimingPlug`.

  ## Usage

      import Bonfire.UI.Common.Timing

      # Single measurement (overwrites previous value for the same key):
      time_section :my_operation do
        expensive_work()
      end

      # Accumulating measurement (adds to previous value for the same key):
      time_section_accumulate :maybe_component do
        work_called_many_times()
      end
  """

  @page_profiler_enabled System.get_env("PAGE_PROFILER_ENABLED") in ~w(true yes 1)

  @doc "Instruments a block, recording wall-clock time under `key`. Overwrites any previous value for the same key."
  defmacro time_section(key, do: block) do
    if @page_profiler_enabled do
      quote do
        if Process.get(:server_timing_start) do
          unquote(__MODULE__).__measure__(unquote(key), fn -> unquote(block) end)
        else
          unquote(block)
        end
      end
    else
      block
    end
  end

  @doc "Like `time_section/2`, but accumulates time across multiple calls for the same key."
  defmacro time_section_accumulate(key, do: block) do
    if @page_profiler_enabled do
      quote do
        if Process.get(:server_timing_start) do
          unquote(__MODULE__).__measure_accumulate__(unquote(key), fn -> unquote(block) end)
        else
          unquote(block)
        end
      end
    else
      block
    end
  end

  @doc false
  def __measure__(key, fun) do
    t = System.monotonic_time(:microsecond)
    result = fun.()

    Bonfire.UI.Common.ServerTimingPlug.record_custom(
      key,
      System.monotonic_time(:microsecond) - t
    )

    result
  end

  @doc false
  def __measure_accumulate__(key, fun) do
    t = System.monotonic_time(:microsecond)
    result = fun.()

    Bonfire.UI.Common.ServerTimingPlug.accumulate_custom(
      key,
      System.monotonic_time(:microsecond) - t
    )

    result
  end
end
