defmodule Bonfire.UI.Common.ConfigSettingsListLive do
  @moduledoc """
  LiveView for displaying registered configuration and settings keys.
  """
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.ConfigSettingsRegistry

  prop settings, :list

  # Helper functions

  # defp format_key(key) when is_list(key), do: Enum.join(key, ".")
  # defp format_key(key), do: to_string(key)

  defp format_value(nil), do: nil
  defp format_value(value) when is_function(value), do: "#Function<...>"
  defp format_value(value) when is_pid(value), do: "#PID<...>"
  defp format_value(value) when is_port(value), do: "#Port<...>"
  defp format_value(value) when is_reference(value), do: "#Reference<...>"
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_atom(value), do: to_string(value)

  defp format_value(value) when is_list(value) do
    if Keyword.keyword?(value) do
      # Format keyword lists for display
      Enum.map(value, fn {k, v} -> {k, format_value(v)} end)
    else
      # Handle regular lists
      Enum.map(value, &format_value/1)
    end
    |> inspect_value()
  end

  defp format_value(value) when is_map(value) do
    for {k, v} <- value, into: %{} do
      {format_value(k), format_value(v)}
    end
    |> inspect_value()
  end

  defp format_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&format_value/1)
    |> inspect_value()
  end

  # defp format_value(value) when is_list(value) or is_map(value) or is_tuple(value), do: inspect_value(value)
  # inspect_value(value)
  defp format_value(value), do: value

  defp inspect_value(value), do: inspect(value, pretty: true, limit: 1000)

  defp format_key_for_display(key) when is_list(key) do
    key
    |> Enum.map(&format_key_for_display/1)
    |> Enum.join(".")
  end

  defp format_key_for_display(key) when is_atom(key) do
    to_string(key)
  end

  defp format_key_for_display(key) do
    inspect(key)
  end
end
