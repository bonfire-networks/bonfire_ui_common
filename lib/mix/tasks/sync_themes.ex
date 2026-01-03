defmodule Mix.Tasks.Bonfire.SyncThemes do
  use Mix.Task

  @shortdoc "Synchronize DaisyUI themes from config to CSS"

  @app_css_path "assets/css/app.css"
  @custom_themes_path "assets/css/custom_themes.css"
  # Regex pattern defined as a function to comply with Erlang/OTP 28
  defp daisyui_config_pattern, do: ~r/@plugin "daisyui" \{[^}]*\}/s

  defp app_css_path do
    cond do
      File.exists?(@app_css_path) ->
        @app_css_path

      File.exists?("extensions/bonfire_ui_common/#{@app_css_path}") ->
        @app_css_path

      File.exists?("deps/bonfire_ui_common/#{@app_css_path}") ->
        "deps/bonfire_ui_common/#{@app_css_path}"
    end
  end

  defp custom_themes_path do
    cond do
      File.exists?(@custom_themes_path) ->
        @custom_themes_path

      File.exists?("extensions/bonfire_ui_common/#{@custom_themes_path}") ->
        @custom_themes_path

      File.exists?("deps/bonfire_ui_common/#{@custom_themes_path}") ->
        "deps/bonfire_ui_common/#{@custom_themes_path}"
    end
  end

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
    # TODO: Custom themes parsing needs more work to handle complex nested structures
    # custom_themes = get_custom_themes_from_config(config)

    Mix.shell().info(
      "Found #{length(light_themes)} light themes and #{length(dark_themes)} dark themes"
    )

    if Enum.empty?(light_themes) and Enum.empty?(dark_themes) do
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
    # TODO: Re-enable when custom theme parsing is fixed
    custom_theme_configs = ""
    # custom_theme_configs =
    #   Enum.map(custom_themes, &generate_custom_theme_config/1)
    #   |> Enum.join("\n\n")

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

  # TODO: Custom themes parsing - needs refactoring to handle complex nested structures
  # Consider using Application.get_env/3 to load config at runtime instead of regex parsing
  #
  # # Extract custom themes from config
  # defp get_custom_themes_from_config(content) do
  #   # Match themes_custom: [ [...], [...], ... ] allowing for multiline and nested content
  #   case Regex.run(~r/themes_custom:\s*\[(.*?)\n\s*\]/s, content) do
  #     [_, themes_content] ->
  #       # Split by "], [" to get individual theme blocks, then clean up brackets
  #       String.split(themes_content, ~r/\],\s*\[/)
  #       |> Enum.map(fn block ->
  #         block
  #         |> String.trim()
  #         |> String.trim_leading("[")
  #         |> String.trim_trailing("]")
  #         |> parse_theme_block()
  #       end)
  #       |> Enum.reject(&is_nil/1)
  #
  #     nil ->
  #       []
  #   end
  # end
  #
  # # Parse individual theme block into a map
  # defp parse_theme_block(block) do
  #   with {:ok, name} <- extract_theme_name(block),
  #        attrs <- parse_theme_attributes(block) do
  #     Map.put(attrs, :name, name)
  #   else
  #     _ -> nil
  #   end
  # end
  #
  # # Extract the theme name from a theme block
  # defp extract_theme_name(block) do
  #   case Regex.run(~r/name:\s*"([^"]+)"/, block) do
  #     [_, name] -> {:ok, name}
  #     nil -> :error
  #   end
  # end
  #
  # # Parse all key-value attributes from a theme block
  # defp parse_theme_attributes(block) do
  #   # Match key-value pairs: "key": "value", "key": value, key: "value", or key: value
  #   # Handles both quoted and unquoted keys, and quoted and unquoted values
  #   Regex.scan(~r/(?:"([\w-]+)"|(\w+)):\s*(?:"([^"]*)"|(\w+))/, block)
  #   |> Enum.map(&parse_attribute/1)
  #   |> Enum.reject(&is_nil/1)
  #   |> Enum.into(%{})
  # end
  #
  # # Parse a single attribute match into {key, value} tuple
  # # Handles: ["full", "quoted_key", "", "quoted_val", ""] or ["full", "", "unquoted_key", "quoted_val", ""]
  # defp parse_attribute([_full_match, quoted_key, unquoted_key, quoted_value, unquoted_value]) do
  #   key = if quoted_key != "", do: quoted_key, else: unquoted_key
  #   # Skip the name attribute as it's handled separately
  #   if key == "name", do: nil, else: build_attribute(key, quoted_value, unquoted_value)
  # end
  #
  # # Handle unexpected match format
  # defp parse_attribute(_other), do: nil
  #
  # # Build attribute tuple from parsed values
  # defp build_attribute(key, quoted_value, unquoted_value) do
  #   normalized_key = normalize_key(key)
  #   value = if quoted_value != "", do: quoted_value, else: parse_literal_value(unquoted_value)
  #   {normalized_key, value}
  # end
  #
  # # Normalize key from config format (with dashes) to atom with underscores
  # defp normalize_key(key) do
  #   key
  #   |> String.replace("-", "_")
  #   |> String.to_atom()
  # end
  #
  # # Parse literal values (booleans, numbers) from strings
  # defp parse_literal_value("true"), do: true
  # defp parse_literal_value("false"), do: false
  # defp parse_literal_value(value), do: value

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

  # TODO: Custom theme generation - disabled until parsing is fixed
  #
  # # Generate custom theme configuration
  # defp generate_custom_theme_config(theme) do
  #   # Helper to safely quote color values if they contain # or start with oklch
  #   quote_value = fn
  #     nil -> "transparent"
  #     value when is_binary(value) ->
  #       if String.starts_with?(value, "#") or String.starts_with?(value, "oklch") do
  #         "\"#{value}\""
  #       else
  #         value
  #       end
  #     value -> value
  #   end
  #
  #   """
  #   @plugin "daisyui/theme" {
  #     name: "#{theme[:name]}";
  #     default: #{theme[:default] || false}; /* set as default */
  #     prefersdark: #{theme[:prefersdark] || false}; /* set as default dark mode */
  #     color-scheme: "#{theme[:color_scheme] || "light"}"; /* color of browser-provided UI */
  #
  #     /* base colors */
  #     --color-base-100: #{quote_value.(theme[:color_base_100] || "oklch(98% 0.02 240)")};
  #     --color-base-200: #{quote_value.(theme[:color_base_200] || "oklch(95% 0.03 240)")};
  #     --color-base-300: #{quote_value.(theme[:color_base_300] || "oklch(92% 0.04 240)")};
  #     --color-base-content: #{quote_value.(theme[:color_base_content] || "oklch(20% 0.05 240)")};
  #
  #     /* primary colors */
  #     --color-primary: #{quote_value.(theme[:color_primary] || "oklch(55% 0.3 240)")};
  #     --color-primary-content: #{quote_value.(theme[:color_primary_content] || "oklch(98% 0.01 240)")};
  #
  #     /* secondary colors */
  #     --color-secondary: #{quote_value.(theme[:color_secondary] || "oklch(70% 0.25 200)")};
  #     --color-secondary-content: #{quote_value.(theme[:color_secondary_content] || "oklch(98% 0.01 200)")};
  #
  #     /* accent colors */
  #     --color-accent: #{quote_value.(theme[:color_accent] || "oklch(65% 0.25 160)")};
  #     --color-accent-content: #{quote_value.(theme[:color_accent_content] || "oklch(98% 0.01 160)")};
  #
  #     /* neutral colors */
  #     --color-neutral: #{quote_value.(theme[:color_neutral] || "oklch(50% 0.05 240)")};
  #     --color-neutral-content: #{quote_value.(theme[:color_neutral_content] || "oklch(98% 0.01 240)")};
  #
  #     /* state colors */
  #     --color-info: #{quote_value.(theme[:color_info] || "oklch(70% 0.2 220)")};
  #     --color-info-content: #{quote_value.(theme[:color_info_content] || "oklch(98% 0.01 220)")};
  #     --color-success: #{quote_value.(theme[:color_success] || "oklch(65% 0.25 140)")};
  #     --color-success-content: #{quote_value.(theme[:color_success_content] || "oklch(98% 0.01 140)")};
  #     --color-warning: #{quote_value.(theme[:color_warning] || "oklch(80% 0.25 80)")};
  #     --color-warning-content: #{quote_value.(theme[:color_warning_content] || "oklch(20% 0.05 80)")};
  #     --color-error: #{quote_value.(theme[:color_error] || "oklch(65% 0.3 30)")};
  #     --color-error-content: #{quote_value.(theme[:color_error_content] || "oklch(98% 0.01 30)")};
  #
  #     /* border radius */
  #     --radius-selector: #{quote_value.(theme[:radius_selector] || "1rem")};
  #     --radius-field: #{quote_value.(theme[:radius_field] || "0.25rem")};
  #     --radius-box: #{quote_value.(theme[:radius_box] || "0.5rem")};
  #
  #     /* base sizes */
  #     --size-selector: #{quote_value.(theme[:size_selector] || "0.25rem")};
  #     --size-field: #{quote_value.(theme[:size_field] || "0.25rem")};
  #
  #     /* border size */
  #     --border: #{quote_value.(theme[:border] || "1px")};
  #
  #     /* effects */
  #     --depth: #{theme[:depth] || "1"};
  #     --noise: #{theme[:noise] || "0"};
  #   }
  #   """
  # end

  # Update the CSS files with new configurations
  defp update_css_file(new_daisyui_config, custom_theme_configs) do
    app_css_path = app_css_path()
    custom_themes_path = custom_themes_path()

    # Ensure main CSS file exists
    if not File.exists?(app_css_path) or not File.exists?(custom_themes_path) do
      Mix.shell().error("CSS file not found at #{app_css_path} and/or #{custom_themes_path}!")
      exit({:shutdown, 1})
    end

    # Read main CSS file content
    css_content = File.read!(app_css_path)

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
    case File.write(app_css_path, updated_css) do
      :ok ->
        Mix.shell().info("DaisyUI theme configuration updated in main CSS!")

      {:error, reason} ->
        Mix.shell().error("Failed to write updated main CSS file: #{inspect(reason)}")
        exit({:shutdown, 1})
    end

    # Write custom themes to separate file (only if we have custom themes)
    if custom_theme_configs != "" do
      case File.write(custom_themes_path, custom_themes_content) do
        :ok ->
          Mix.shell().info("Custom themes successfully synchronized to #{custom_themes_path}!")

        {:error, reason} ->
          Mix.shell().error("Failed to write custom themes file: #{inspect(reason)}")
          exit({:shutdown, 1})
      end
    end

    Mix.shell().info("Theme synchronization completed successfully!")
  end
end
