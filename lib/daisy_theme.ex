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

  @color_names @keys
               |> Enum.map(& &1.name)
               |> Enum.filter(&String.starts_with?(&1, "color-"))

  @key_names Enum.map(@keys, & &1.name)

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
    |> Enum.flat_map(&declaration/1)
    |> Enum.join(" ")
  end

  @doc """
  Like `style_attr/1`, but emits CSS variables **only** for the keys present in
  `config` — without merging in `default_theme/0`.

  Use this for the user/instance *custom* palette: emitting only the variables the
  user actually set lets every other variable fall through to the active base theme
  (`data-theme`), instead of forcing DaisyTheme's defaults onto the whole document.
  """
  def style_attr_overrides(config) when is_map(config) do
    keys = keys()

    config
    |> Enum.flat_map(fn {key, value} ->
      key = to_string(key)

      case Enum.find(keys, &(&1.name == key)) do
        nil -> []
        key_config -> declaration(Map.put(key_config, :value, value))
      end
    end)
    |> Enum.join(" ")
  end

  @doc """
  Normalizes a DaisyUI theme token before storing or emitting it as CSS.

  Colour picker widgets expose bare hex values, while CSS requires the `#` prefix. Other known tokens are kept as simple CSS token values, but declarations with characters that could break out of a CSS custom property are rejected.
  """
  def normalize_value(key, value) do
    key = to_string(key)

    cond do
      key in @color_names ->
        normalize_color_value(value)

      key in @key_names ->
        normalize_css_token(value)

      true ->
        :error
    end
  end

  defp declaration(%{name: key, variable: variable, value: value}) do
    case normalize_value(key, value) do
      {:ok, value} -> ["#{variable}: #{value};"]
      :error -> []
    end
  end

  defp normalize_color_value(value) when is_integer(value) and value <= 16_777_215 do
    {:ok, "#" <> String.pad_leading(Integer.to_string(value, 16), 6, "0")}
  end

  defp normalize_color_value(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      valid_prefixed_hex?(value) ->
        {:ok, value}

      valid_bare_hex?(value) ->
        {:ok, "#" <> value}

      safe_css_token?(value) ->
        {:ok, value}

      true ->
        :error
    end
  end

  defp normalize_color_value(_), do: :error

  defp normalize_css_token(value) when is_binary(value) do
    value = String.trim(value)

    if safe_css_token?(value) do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_css_token(value) when is_integer(value), do: {:ok, Integer.to_string(value)}
  defp normalize_css_token(value) when is_float(value), do: {:ok, Float.to_string(value)}
  defp normalize_css_token(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  defp normalize_css_token(_), do: :error

  defp valid_prefixed_hex?("#" <> hex), do: valid_bare_hex?(hex)
  defp valid_prefixed_hex?(_), do: false

  defp valid_bare_hex?(value),
    do:
      String.match?(
        value,
        ~r/\A(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/
      )

  defp safe_css_token?(value),
    do: value != "" and not String.contains?(value, [";", "{", "}"])
end
