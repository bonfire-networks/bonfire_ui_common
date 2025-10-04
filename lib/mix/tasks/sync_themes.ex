defmodule Mix.Tasks.Bonfire.SyncThemes do
  use Mix.Task

  @shortdoc "Synchronize DaisyUI themes from config to CSS"

  @app_css_path "extensions/bonfire_ui_common/assets/css/app.css"
  @custom_themes_path "extensions/bonfire_ui_common/assets/css/custom_themes.css"
  # Regex pattern defined as a function to comply with Erlang/OTP 28
  defp daisyui_config_pattern, do: ~r/@plugin "daisyui" \{[^}]*\}/s

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
        # Parse attributes - handle both quoted strings and unquoted values (booleans, numbers)
        attrs =
          Regex.scan(~r/(?:\"?([^":\s]+)\"?:|(\w+(?:[_-]\w+)*):)\s*(?:"([^"]+)"|(\w+))/, block)
          |> Enum.map(fn
            # Quoted key with quoted value
            [_, quoted_key, "", quoted_value] when quoted_key != "name" and quoted_value != "" ->
              key = String.replace(quoted_key, "-", "_") |> String.to_atom()
              {key, String.trim(quoted_value)}

            # Quoted key with unquoted value (boolean/number)
            [_, quoted_key, "", "", unquoted_value] when quoted_key != "name" ->
              key = String.replace(quoted_key, "-", "_") |> String.to_atom()
              value = parse_value(unquoted_value)
              {key, value}

            # Unquoted key with quoted value
            [_, "", key, quoted_value] when key != "name" and quoted_value != "" ->
              key = String.replace(key, "-", "_") |> String.to_atom()
              {key, String.trim(quoted_value)}

            # Unquoted key with unquoted value (boolean/number)
            [_, "", key, "", unquoted_value] when key != "name" ->
              key = String.replace(key, "-", "_") |> String.to_atom()
              value = parse_value(unquoted_value)
              {key, value}

            _ ->
              nil
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.into(%{})

        Map.put(attrs, :name, name)

      nil ->
        nil
    end
  end

  # Parse boolean and other literal values
  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(value), do: value

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
    # Helper to quote color values if they contain # or start with oklch
    quote_value = fn value ->
      if String.starts_with?(value, "#") or String.starts_with?(value, "oklch") do
        "\"#{value}\""
      else
        value
      end
    end

    """
    @plugin "daisyui/theme" {
      name: "#{theme[:name]}";
      default: #{theme[:default] || false}; /* set as default */
      prefersdark: #{theme[:prefersdark] || false}; /* set as default dark mode */
      color-scheme: "#{theme[:color_scheme] || "light"}"; /* color of browser-provided UI */

      /* base colors */
      --color-base-100: #{quote_value.(theme[:color_base_100] || "oklch(98% 0.02 240)")};
      --color-base-200: #{quote_value.(theme[:color_base_200] || "oklch(95% 0.03 240)")};
      --color-base-300: #{quote_value.(theme[:color_base_300] || "oklch(92% 0.04 240)")};
      --color-base-content: #{quote_value.(theme[:color_base_content] || "oklch(20% 0.05 240)")};

      /* primary colors */
      --color-primary: #{quote_value.(theme[:color_primary] || "oklch(55% 0.3 240)")};
      --color-primary-content: #{quote_value.(theme[:color_primary_content] || "oklch(98% 0.01 240)")};

      /* secondary colors */
      --color-secondary: #{quote_value.(theme[:color_secondary] || "oklch(70% 0.25 200)")};
      --color-secondary-content: #{quote_value.(theme[:color_secondary_content] || "oklch(98% 0.01 200)")};

      /* accent colors */
      --color-accent: #{quote_value.(theme[:color_accent] || "oklch(65% 0.25 160)")};
      --color-accent-content: #{quote_value.(theme[:color_accent_content] || "oklch(98% 0.01 160)")};

      /* neutral colors */
      --color-neutral: #{quote_value.(theme[:color_neutral] || "oklch(50% 0.05 240)")};
      --color-neutral-content: #{quote_value.(theme[:color_neutral_content] || "oklch(98% 0.01 240)")};

      /* state colors */
      --color-info: #{quote_value.(theme[:color_info] || "oklch(70% 0.2 220)")};
      --color-info-content: #{quote_value.(theme[:color_info_content] || "oklch(98% 0.01 220)")};
      --color-success: #{quote_value.(theme[:color_success] || "oklch(65% 0.25 140)")};
      --color-success-content: #{quote_value.(theme[:color_success_content] || "oklch(98% 0.01 140)")};
      --color-warning: #{quote_value.(theme[:color_warning] || "oklch(80% 0.25 80)")};
      --color-warning-content: #{quote_value.(theme[:color_warning_content] || "oklch(20% 0.05 80)")};
      --color-error: #{quote_value.(theme[:color_error] || "oklch(65% 0.3 30)")};
      --color-error-content: #{quote_value.(theme[:color_error_content] || "oklch(98% 0.01 30)")};

      /* border radius */
      --radius-selector: #{quote_value.(theme[:radius_selector] || "1rem")};
      --radius-field: #{quote_value.(theme[:radius_field] || "0.25rem")};
      --radius-box: #{quote_value.(theme[:radius_box] || "0.5rem")};

      /* base sizes */
      --size-selector: #{quote_value.(theme[:size_selector] || "0.25rem")};
      --size-field: #{quote_value.(theme[:size_field] || "0.25rem")};

      /* border size */
      --border: #{quote_value.(theme[:border] || "1px")};

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
    unless Regex.match?(daisyui_config_pattern(), css_content) do
      Mix.shell().error("Could not find DaisyUI configuration in CSS file!")
      exit({:shutdown, 1})
    end

    # Update the daisyui config (theme list) in main CSS
    updated_css = Regex.replace(daisyui_config_pattern(), css_content, new_daisyui_config)

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
