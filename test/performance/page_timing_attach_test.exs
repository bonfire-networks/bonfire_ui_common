defmodule Bonfire.UI.Common.PageTimingAttachTest do
  # async: false — mutates globally-named telemetry handlers
  use ExUnit.Case, async: false

  alias Bonfire.UI.Common.PageTimingStorage

  defp profiling_handler_ids do
    :telemetry.list_handlers([])
    |> Enum.map(& &1.id)
    |> Enum.filter(fn
      id when is_binary(id) ->
        String.starts_with?(id, "bonfire-server-timing") or
          String.starts_with?(id, "bonfire-page-timing")

      _ ->
        false
    end)
  end

  setup do
    if is_nil(Process.whereis(PageTimingStorage)), do: start_supervised!(PageTimingStorage)
    PageTimingStorage.disable()
    on_exit(fn -> PageTimingStorage.disable() end)
    :ok
  end

  test "profiling telemetry handlers attach on enable and detach on disable (zero cost when off)" do
    assert profiling_handler_ids() == []

    assert :ok = PageTimingStorage.enable()
    ids = profiling_handler_ids()
    assert Enum.any?(ids, &String.starts_with?(&1, "bonfire-server-timing"))
    assert "bonfire-page-timing-liveview" in ids

    assert :ok = PageTimingStorage.disable()
    assert profiling_handler_ids() == []
  end
end
