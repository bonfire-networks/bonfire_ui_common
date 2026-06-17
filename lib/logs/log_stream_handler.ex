defmodule Bonfire.UI.Common.LogStreamHandler do
  @moduledoc """
  An Erlang `:logger` handler that fans every (matching) log event out over `Bonfire.Common.PubSub` so the admin LiveDashboard logs page can stream logs in real time.

  Lifecycle (attach/detach) and the live filter are owned by `Bonfire.UI.Common.LogStreamManager` — this module only formats and broadcasts.

  Filtering happens **at the source**: `:logger` enforces the handler `:level` first (cheapest gate), then `log/2` applies the optional `:query`/`:modules` filter carried in the handler config *before* formatting or broadcasting, so non-matching events never reach PubSub.

  IMPORTANT: never call `Logger`/`Untangle` (or anything that logs) from inside `log/2` — it would feed back into this handler and loop. Hence the bare `try/catch` and raw `Phoenix.PubSub.broadcast/3` (not `Bonfire.Common.PubSub.broadcast/2`, which logs).
  """

  @handler_id :bonfire_log_stream
  @topic "bonfire:log_stream"
  @pubsub Bonfire.Common.PubSub
  # CSI sequences (colors, italics, etc.): ESC [ … <letter>
  @ansi ~r/\x1b\[[0-9;?]*[ -\/]*[@-~]/

  def handler_id, do: @handler_id
  def topic, do: @topic

  @doc "`:logger` handler callback. `config` is the handler config map; our filter lives under `:config`."
  def log(%{level: level, msg: msg, meta: meta}, config) do
    filter = Map.get(config, :config, %{})

    if module_match?(meta, filter) do
      # Keep the raw message (Untangle embeds ANSI colors) — the page renders them as HTML.
      message = format_msg(msg)

      if query_match?(message, meta, filter) do
        event = %{
          level: level,
          time: meta[:time],
          message: message,
          module: meta[:mfa] && elem(meta[:mfa], 0),
          pid: meta[:pid] && inspect(meta[:pid]),
          node: node()
        }

        Phoenix.PubSub.broadcast(@pubsub, @topic, {:log_event, event})
      end
    end

    :ok
  catch
    # never log here (would loop back into this handler)
    _, _ -> :ok
  end

  defp module_match?(_meta, %{modules: nil}), do: true
  defp module_match?(_meta, filter) when not is_map_key(filter, :modules), do: true

  defp module_match?(meta, %{modules: modules}) when is_list(modules) and modules != [] do
    case meta[:mfa] do
      {mod, _, _} -> mod in modules
      _ -> false
    end
  end

  defp module_match?(_meta, _filter), do: true

  defp query_match?(_message, _meta, %{query: nil}), do: true
  defp query_match?(_message, _meta, filter) when not is_map_key(filter, :query), do: true
  defp query_match?(_message, _meta, %{query: ""}), do: true

  defp query_match?(message, meta, %{query: query}) when is_binary(query) do
    # match against ANSI-stripped text so escape codes don't break multi-token queries
    haystack = strip_ansi(message) <> " " <> inspect(meta[:mfa])
    String.contains?(String.downcase(haystack), String.downcase(query))
  end

  defp query_match?(_message, _meta, _filter), do: true

  defp strip_ansi(string), do: String.replace(string, @ansi, "")

  # `:logger` message shapes
  defp format_msg({:string, str}), do: IO.iodata_to_binary(str)
  defp format_msg({:report, report}) when is_map(report), do: inspect(report)
  defp format_msg({:report, report}), do: inspect(report)

  defp format_msg({format, args}) when is_list(args) do
    :io_lib.format(format, args) |> IO.iodata_to_binary()
  end

  defp format_msg(other), do: inspect(other)
end
