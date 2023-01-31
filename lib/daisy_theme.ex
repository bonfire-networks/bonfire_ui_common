defmodule DaisyTheme do
  @keys [
    %{name: "primary", variable: "--p"},
    %{name: "primary-focus", variable: "--pf"},
    %{name: "primary-content", variable: "--pc"},
    %{name: "secondary", variable: "--s"},
    %{name: "secondary-focus", variable: "--sf"},
    %{name: "secondary-content", variable: "--sc"},
    %{name: "accent", variable: "--a"},
    %{name: "accent-focus", variable: "--af"},
    %{name: "accent-content", variable: "--ac"},
    %{name: "neutral", variable: "--n"},
    %{name: "neutral-focus", variable: "--nf"},
    %{name: "neutral-content", variable: "--nc"},
    %{name: "base-100", variable: "--b1"},
    %{name: "base-200", variable: "--b2"},
    %{name: "base-300", variable: "--b3"},
    %{name: "base-content", variable: "--bc"},
    %{name: "info", variable: "--in"},
    %{name: "info-content", variable: "--inc"},
    %{name: "success", variable: "--su"},
    %{name: "success-content", variable: "--suc"},
    %{name: "warning", variable: "--wa"},
    %{name: "warning-content", variable: "--wac"},
    %{name: "error", variable: "--er"},
    %{name: "error-content", variable: "--erc"}
  ]

  @default_theme %{
    "primary" => "#fde047",
    "secondary" => "#D926AA",
    "accent" => "#1FB2A5",
    "neutral" => "#191D24",
    "base-100" => "#2A303C",
    "info" => "#3ABFF8",
    "success" => "#36D399",
    "warning" => "#FBBD23",
    "error" => "#F87272"
  }

  def keys, do: @keys
  def default_theme, do: @default_theme

  def theme(config), do: Map.merge(default_theme(), config)

  def generate(config \\ %{}) do
    keys = keys()

    theme =
      theme(config)
      |> IO.inspect()

    Enum.map(
      theme,
      fn {key, colour} ->
        Enum.find(keys, &(&1.name == key))
        |> Map.put(:value, colour)
      end
    )

    # ++ [
    #   darker(theme, "primary-focus", "--pf", "primary"),
    #   darker(theme, "secondary-focus", "--sf", "secondary"),
    #   darker(theme, "accent-focus", "--af", "accent"),
    #   darker(theme, "neutral-focus", "--nf", "neutral"),
    #   darker(theme, "base-200", "--b2", "base-100", 0.1),
    #   darker(theme, "base-300", "--b3", "base-100", 0.2),

    #   adjust(theme, "base-content", "--bc", "base-100"),
    #   adjust(theme, "primary-content", "--pc", "primary"),
    #   adjust(theme, "secondary-content", "--sc", "secondary"),
    #   adjust(theme, "accent-content", "--ac", "accent"),
    #   adjust(theme, "neutral-content", "--nc", "neutral"),
    #   adjust(theme, "info-content", "--inc", "info"),
    #   adjust(theme, "success-content", "--suc", "success"),
    #   adjust(theme, "warning-content", "--wac", "warning"),
    #   adjust(theme, "error-content", "--erc", "error")
    # ]
  end

  def style_attr(config \\ %{}) do
    generate(config)
    |> Enum.map(
      #  name: name,
      fn %{
           variable: variable,
           value: value
         } ->
        colours =
          value
          |> Chameleon.convert(Chameleon.HSL)

        "#{variable}: #{colours.h} #{colours.s}% #{colours.l}%;"
      end
    )
    |> Enum.join(" ")
  end

  def darker(theme, name, variable, field, percent \\ 0.2) do
    %{
      name: name,
      variable: variable,
      value: darken(theme[field] || 0, percent)
    }
  end

  def adjust(theme, name, variable, field, percent \\ 0.8) do
    value = theme[field] || 0

    case is_dark?(value) do
      true -> %{name: name, variable: variable, value: darken(value, percent)}
      false -> %{name: name, variable: variable, value: lighten(value, percent)}
    end
  end

  def is_dark?(value) do
    value
    |> Chameleon.convert(Chameleon.HSL)
    |> then(&(&1.l < 70))
  end

  def lighten(hex, amount) do
    darken(hex, -amount)
  end

  def darken(hex, amount) do
    hex
    |> Chameleon.convert(Chameleon.HSL)
    |> then(fn %{l: l} = hsl -> %{hsl | l: clamp(l - amount, 0, 100)} end)
  end

  #   def darken(hex, amount) do
  #     hex
  #        |> Chameleon.convert(Chameleon.RGB)
  #        |> Map.from_struct()
  #        |> Map.values()
  #        |> Enum.map(fn
  #          x -> clamp(x - amount, 0, 255)
  #        end)
  #        |> then(fn [r, g, b] -> Chameleon.RGB.new(r, g, b) end)
  #     #    |> Chameleon.convert(Chameleon.Hex)
  #     #    |> Map.get(:hex)
  #   end

  def clamp(value, min, max) do
    min = if min < max, do: min, else: max
    max = if min < max, do: max, else: min

    if value < min do
      min
    else
      if value > max, do: max, else: value
    end
  end
end
