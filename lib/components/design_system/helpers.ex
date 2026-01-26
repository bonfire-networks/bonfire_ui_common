defmodule Bonfire.UI.Common.DesignSystem.Helpers do
  @moduledoc """
  Shared helper functions for design system components.
  These handle common patterns like Phoenix LiveView attribute conversion.
  """

  @doc """
  Convert a map of phx_values to phx-value-* attributes.
  Uses string keys to avoid atom table exhaustion from dynamic input.

  ## Examples

      iex> Bonfire.UI.Common.DesignSystem.Helpers.phx_value_attrs(%{id: 123, name: "test"})
      [{"phx-value-id", 123}, {"phx-value-name", "test"}]

      iex> Bonfire.UI.Common.DesignSystem.Helpers.phx_value_attrs(nil)
      []
  """
  def phx_value_attrs(values) when is_map(values) do
    Enum.map(values, fn {key, value} ->
      {"phx-value-#{key}", value}
    end)
  end

  def phx_value_attrs(_), do: []

  @doc """
  Build rate limiting attributes (throttle or debounce) as a list.
  Returns an empty list if neither is set.

  ## Examples

      iex> Bonfire.UI.Common.DesignSystem.Helpers.rate_limit_attrs(500, nil)
      [{"phx-throttle", 500}]

      iex> Bonfire.UI.Common.DesignSystem.Helpers.rate_limit_attrs(nil, 300)
      [{"phx-debounce", 300}]

      iex> Bonfire.UI.Common.DesignSystem.Helpers.rate_limit_attrs(nil, nil)
      []
  """
  def rate_limit_attrs(throttle, _debounce) when is_integer(throttle),
    do: [{"phx-throttle", throttle}]

  def rate_limit_attrs(_throttle, debounce) when is_integer(debounce),
    do: [{"phx-debounce", debounce}]

  def rate_limit_attrs(_, _), do: []
end
