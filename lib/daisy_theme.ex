defmodule DaisyTheme do
  @keys [
    %{name: "color-primary", variable: "--color-primary"},
    %{name: "color-primary-content", variable: "--color-primary-content"},
    %{name: "color-secondary", variable: "--color-secondary"},
    %{name: "color-secondary-content", variable: "--color-secondary-content"},
    %{name: "color-accent", variable: "--color-accent"},
    %{name: "color-accent-content", variable: "--color-accent-content"},
    %{name: "color-neutral", variable: "--color-neutral"},
    %{name: "color-neutral-content", variable: "--color-neutral-content"},
    %{name: "color-base-100", variable: "--color-base-100"},
    %{name: "color-base-200", variable: "--color-base-200"},
    %{name: "color-base-300", variable: "--color-base-300"},
    %{name: "color-base-content", variable: "--color-base-content"},
    %{name: "color-info", variable: "--color-info"},
    %{name: "color-info-content", variable: "--color-info-content"},
    %{name: "color-success", variable: "--color-success"},
    %{name: "color-success-content", variable: "--color-success-content"},
    %{name: "color-warning", variable: "--color-warning"},
    %{name: "color-warning-content", variable: "--color-warning-content"},
    %{name: "color-error", variable: "--color-error"},
    %{name: "color-error-content", variable: "--color-error-content"},
    %{name: "radius-selector", variable: "--radius-selector"},
    %{name: "radius-field", variable: "--radius-field"},
    %{name: "radius-box", variable: "--radius-box"},
    %{name: "size-selector", variable: "--size-selector"},
    %{name: "size-field", variable: "--size-field"},
    %{name: "border", variable: "--border"},
    %{name: "depth", variable: "--depth"},
    %{name: "noise", variable: "--noise"}
  ]

  # Using hex color defaults
  @default_theme %{
    # Blue
    "color-primary" => "#1D4ED8",
    # White
    "color-primary-content" => "#FFFFFF",
    # Purple
    "color-secondary" => "#9333EA",
    # White
    "color-secondary-content" => "#FFFFFF",
    # Green
    "color-accent" => "#10B981",
    # White
    "color-accent-content" => "#FFFFFF",
    # Dark gray
    "color-neutral" => "#1F2937",
    # White
    "color-neutral-content" => "#FFFFFF",
    # White
    "color-base-100" => "#FFFFFF",
    # Light gray
    "color-base-200" => "#F3F4F6",
    # Lighter gray
    "color-base-300" => "#E5E7EB",
    # Dark gray
    "color-base-content" => "#1F2937",
    # Info blue
    "color-info" => "#0EA5E9",
    # White
    "color-info-content" => "#FFFFFF",
    # Success green
    "color-success" => "#10B981",
    # White
    "color-success-content" => "#FFFFFF",
    # Warning yellow
    "color-warning" => "#F59E0B",
    # Dark gray
    "color-warning-content" => "#1F2937",
    # Error red
    "color-error" => "#EF4444",
    # White
    "color-error-content" => "#FFFFFF",
    "radius-selector" => "1rem",
    "radius-field" => "0.25rem",
    "radius-box" => "0.5rem",
    "size-selector" => "0.25rem",
    "size-field" => "0.25rem",
    "border" => "1px",
    "depth" => "1",
    "noise" => "0"
  }

  def keys, do: @keys
  def default_theme, do: @default_theme

  def theme(config), do: Map.merge(default_theme(), config)

  def generate(config \\ %{}) do
    keys = keys()
    theme = theme(config)

    # Filter only the keys that exist in our @keys list
    Enum.flat_map(
      theme,
      fn {key, colour} ->
        case Enum.find(keys, &(&1.name == key)) do
          # Skip keys that don't match our defined keys
          nil -> []
          found -> [Map.put(found, :value, colour)]
        end
      end
    )
  end

  def style_attr(config \\ %{}) do
    generate(config)
    |> Enum.map(fn %{
                     variable: variable,
                     value: value
                   } ->
      # Format the value based on its type
      formatted_value = format_value(value)
      "#{variable}: #{formatted_value};"
    end)
    |> Enum.join(" ")
  end

  # Format values for CSS
  defp format_value(value) when is_binary(value), do: value

  defp format_value(value) when is_integer(value) do
    # Convert integer to hex string if it looks like a color
    # Maximum value for a 24-bit color (0xFFFFFF)
    if value <= 16_777_215 do
      "#" <> String.pad_leading(Integer.to_string(value, 16), 6, "0")
    else
      Integer.to_string(value)
    end
  end

  defp format_value(value) when is_float(value), do: Float.to_string(value)
  defp format_value(value) when is_atom(value), do: Atom.to_string(value)
  # Default for unsupported types
  defp format_value(_), do: "#000000"
end
