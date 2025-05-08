defmodule Bonfire.UI.Common.ConfigSettingsListLive do
  @moduledoc """
  LiveView for displaying registered configuration and settings keys.
  """
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.ConfigSettingsRegistry
  alias Bonfire.Common.Settings.LiveHandler

  prop settings, :list
  prop scope, :any, default: nil
  prop editable?, :boolean, default: false

  # Helper functions

  def find_type(declared_type, current_value, default_value) do
    current_value_type =
      Types.typeof(current_value)
      |> debug("current_value_type")

    default_value_type =
      Types.typeof(default_value)
      |> debug("default_value_type")

    cond do
      declared_type ->
        declared_type

      default_value_type == current_value_type ->
        default_value_type

      default_value_type == :empty ->
        current_value_type

      current_value_type == :empty ->
        default_value_type

      true ->
        nil
    end
  end

  # def format_key(key) when is_list(key), do: Enum.join(key, ".")
  # def format_key(key), do: to_string(key)

  def format_value(nil), do: nil
  def format_value(value) when is_function(value), do: "#Function<...>"
  def format_value(value) when is_pid(value), do: "#PID<...>"
  def format_value(value) when is_port(value), do: "#Port<...>"
  def format_value(value) when is_reference(value), do: "#Reference<...>"
  def format_value(value) when is_binary(value), do: value
  def format_value(value) when is_atom(value), do: to_string(value)

  def format_value(value) when is_list(value) do
    if Keyword.keyword?(value) do
      # Format keyword lists for display
      Enum.map(value, fn {k, v} -> {k, format_value(v)} end)
    else
      # Handle regular lists
      Enum.map(value, &format_value/1)
    end
    |> inspect_value()
  end

  def format_value(value) when is_struct(value) do
    struct_to_map(value)
    |> format_value()
  end

  def format_value(value) when is_map(value) do
    for {k, v} <- value, into: %{} do
      {format_value(k), format_value(v)}
    end
    |> inspect_value()
  end

  def format_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&format_value/1)
    |> inspect_value()
  end

  # def format_value(value) when is_list(value) or is_map(value) or is_tuple(value), do: inspect_value(value)
  # inspect_value(value)
  def format_value(value), do: value

  def inspect_value(value) when is_binary(value), do: value
  def inspect_value(value), do: inspect(value, pretty: true, limit: 300)

  def format_key_for_display(key) when is_list(key) do
    key
    |> Enum.map(&format_key_for_display/1)
    |> Enum.join(".")
  end

  def format_key_for_display(key) when is_atom(key) do
    to_string(key)
  end

  def format_key_for_display(key) do
    inspect(key)
  end
end
