defmodule Mix.Tasks.Bonfire.SyncThemes do
  use Mix.Task

  @shortdoc "Synchronize DaisyUI themes from config to CSS"

  @app_css_path "extensions/bonfire_ui_common/assets/css/app.css"
  @custom_themes_path "extensions/bonfire_ui_common/assets/css/custom_themes.css"
  @daisyui_config_pattern ~r/@plugin "daisyui" \{[^}]*\}/s
  @config_paths [
    # Project root config
    "config/bonfire_ui_common.exs"
  ]
  # Set to true for more verbose debugging
  @debug false

  def run(args) do
    # Check for --debug flag
    debug = @debug or Enum.member?(args, "--debug")
    if debug, do: Mix.shell().info("DEBUG MODE ENABLED")

    # Load themes from configuration files
    Mix.shell().info("Loading themes from config files...")
    config = load_themes_from_config()

    # Extract themes from config
    light_themes = get_themes_from_config(config, :themes_light)
    dark_themes = get_themes_from_config(config, :themes_dark)
    custom_themes = get_custom_themes_from_config(config)

    Mix.shell().info(
      "Found #{length(light_themes)} light themes, #{length(dark_themes)} dark themes, and #{length(custom_themes)} custom themes"
    )

    if Enum.empty?(light_themes) and Enum.empty?(dark_themes) and Enum.empty?(custom_themes) do
      Mix.shell().error(
        "No themes found in configuration! Check your bonfire_ui_common.exs file."
      )

      exit({:shutdown, 1})
    end

    # Format themes with appropriate flags
    formatted_themes = format_themes(light_themes, dark_themes)
    theme_list = Enum.join(formatted_themes, ", ")

    # Create new DaisyUI config section
    new_daisyui_config = """
    @plugin "daisyui" {
      themes: #{theme_list};
    }
    """

    # Generate custom theme configurations
    custom_theme_configs =
      Enum.map(custom_themes, &generate_custom_theme_config/1)
      |> Enum.join("\n\n")

    # Update CSS file
    update_css_file(new_daisyui_config, custom_theme_configs)
  end

  # Load themes from configuration files
  defp load_themes_from_config do
    Enum.reduce_while(@config_paths, nil, fn config_path, _acc ->
      case File.read(config_path) do
        {:ok, content} -> {:halt, content}
        {:error, _} -> {:cont, nil}
      end
    end) || ""
  end

  # Extract themes list from config using key
  defp get_themes_from_config(content, key) do
    case Regex.run(~r/#{key}:\s*\[(.*?)\]/s, content) do
      [_, list] ->
        Regex.scan(~r/"([^"]+)"/, list)
        |> Enum.map(fn [_, value] -> value end)
        |> Enum.reject(&is_nil/1)

      nil ->
        []
    end
  end

  # Extract custom themes from config
  defp get_custom_themes_from_config(content) do
    case Regex.run(~r/themes_custom:\s*\[\s*\[(.*?)\]\s*\]/s, content) do
      [_, list] ->
        # Parse the theme block directly since it's a single nested list
        [parse_theme_block(list)]
        |> Enum.reject(&is_nil/1)

      nil ->
        []
    end
  end

  # Parse individual theme block
  defp parse_theme_block(block) do
    # Extract name first
    case Regex.run(~r/name:\s*"([^"]+)"/, block) do
      [_, name] ->
        # Then parse other attributes
        attrs =
          Regex.scan(~r/(?:\"?([^"]+)\"?:|(\w+(?:-\w+)?):)\s*"?([^"\],]+)"?/, block)
          |> Enum.map(fn
            [_, quoted_key, "", value] -> {String.to_atom(quoted_key), String.trim(value, ", ")}
            [_, "", key, value] -> {String.to_atom(key), String.trim(value, ", ")}
          end)
          |> Enum.into(%{})

        Map.put(attrs, :name, name)

      nil ->
        nil
    end
  end

  # Format themes with appropriate flags
  defp format_themes(light_themes, dark_themes) do
    light_themes_formatted =
      light_themes
      |> Enum.map(fn
        "light" -> "light --default"
        theme -> theme
      end)

    dark_themes_formatted =
      dark_themes
      |> Enum.map(fn
        "dark" -> "dark --prefersdark"
        theme -> theme
      end)

    light_themes_formatted ++ dark_themes_formatted
  end

  # Generate custom theme configuration
  defp generate_custom_theme_config(theme) do
    """
    @plugin "daisyui/theme" {
      name: "#{theme[:name]}";
      default: #{theme[:default] || false}; /* set as default */
      prefersdark: #{theme[:prefersdark] || false}; /* set as default dark mode */
      color-scheme: "#{theme[:color_scheme] || "light"}"; /* color of browser-provided UI */

      /* base colors */
      --color-base-100: #{theme[:"color-base-100"] || "oklch(98% 0.02 240)"};
      --color-base-200: #{theme[:"color-base-200"] || "oklch(95% 0.03 240)"};
      --color-base-300: #{theme[:"color-base-300"] || "oklch(92% 0.04 240)"};
      --color-base-content: #{theme[:"color-base-content"] || "oklch(20% 0.05 240)"};

      /* primary colors */
      --color-primary: #{theme[:"color-primary"] || "oklch(55% 0.3 240)"};
      --color-primary-content: #{theme[:"color-primary-content"] || "oklch(98% 0.01 240)"};

      /* secondary colors */
      --color-secondary: #{theme[:"color-secondary"] || "oklch(70% 0.25 200)"};
      --color-secondary-content: #{theme[:"color-secondary-content"] || "oklch(98% 0.01 200)"};

      /* accent colors */
      --color-accent: #{theme[:"color-accent"] || "oklch(65% 0.25 160)"};
      --color-accent-content: #{theme[:"color-accent-content"] || "oklch(98% 0.01 160)"};

      /* neutral colors */
      --color-neutral: #{theme[:"color-neutral"] || "oklch(50% 0.05 240)"};
      --color-neutral-content: #{theme[:"color-neutral-content"] || "oklch(98% 0.01 240)"};

      /* state colors */
      --color-info: #{theme[:"color-info"] || "oklch(70% 0.2 220)"};
      --color-info-content: #{theme[:"color-info-content"] || "oklch(98% 0.01 220)"};
      --color-success: #{theme[:"color-success"] || "oklch(65% 0.25 140)"};
      --color-success-content: #{theme[:"color-success-content"] || "oklch(98% 0.01 140)"};
      --color-warning: #{theme[:"color-warning"] || "oklch(80% 0.25 80)"};
      --color-warning-content: #{theme[:"color-warning-content"] || "oklch(20% 0.05 80)"};
      --color-error: #{theme[:"color-error"] || "oklch(65% 0.3 30)"};
      --color-error-content: #{theme[:"color-error-content"] || "oklch(98% 0.01 30)"};

      /* border radius */
      --radius-selector: #{theme[:"radius-selector"] || "1rem"};
      --radius-field: #{theme[:"radius-field"] || "0.25rem"};
      --radius-box: #{theme[:"radius-box"] || "0.5rem"};

      /* base sizes */
      --size-selector: #{theme[:"size-selector"] || "0.25rem"};
      --size-field: #{theme[:"size-field"] || "0.25rem"};

      /* border size */
      --border: #{theme[:border] || "1px"};

      /* effects */
      --depth: #{theme[:depth] || "1"};
      --noise: #{theme[:noise] || "0"};
    }
    """
  end

  # Update the CSS files with new configurations
  defp update_css_file(new_daisyui_config, custom_theme_configs) do
    # Ensure main CSS file exists
    unless File.exists?(@app_css_path) do
      Mix.shell().error("CSS file not found at #{@app_css_path}!")
      exit({:shutdown, 1})
    end

    # Read main CSS file content
    css_content = File.read!(@app_css_path)

    # Ensure daisyui plugin pattern exists in main CSS
    unless Regex.match?(@daisyui_config_pattern, css_content) do
      Mix.shell().error("Could not find DaisyUI configuration in CSS file!")
      exit({:shutdown, 1})
    end

    # Update the daisyui config (theme list) in main CSS
    updated_css = Regex.replace(@daisyui_config_pattern, css_content, new_daisyui_config)

    # Create custom themes content with proper header
    custom_themes_content = """
    /* Custom themes for Bonfire UI */

    #{custom_theme_configs}
    """

    # Write updated main CSS
    case File.write(@app_css_path, updated_css) do
      :ok ->
        Mix.shell().info("DaisyUI theme configuration updated in main CSS!")

      {:error, reason} ->
        Mix.shell().error("Failed to write updated main CSS file: #{inspect(reason)}")
        exit({:shutdown, 1})
    end

    # Write custom themes to separate file
    case File.write(@custom_themes_path, custom_themes_content) do
      :ok ->
        Mix.shell().info("Custom themes successfully synchronized to #{@custom_themes_path}!")

      {:error, reason} ->
        Mix.shell().error("Failed to write custom themes file: #{inspect(reason)}")
        exit({:shutdown, 1})
    end

    Mix.shell().info("Theme synchronization completed successfully!")
  end
end
