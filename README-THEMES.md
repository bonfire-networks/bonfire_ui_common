# Bonfire Theme System

This document explains how to add custom themes to Bonfire using the DaisyUI plugin.

## Overview

Bonfire uses DaisyUI for theming, which allows both predefined themes and custom themes. The system is designed to:

1. Support centralized management of themes in bonfire_ui_common.exs
2. Support both existing DaisyUI themes and custom theme definitions 
3. Allow easy addition of new themes

## How It Works

All themes are defined in the `bonfire_ui_common.exs` configuration file and loaded into DaisyUI by the theme system. This approach ensures that:

1. Themes are managed in a single place
2. Custom themes can be easily added through configuration
3. The ThemeManager provides common utilities for working with themes

## Adding Custom Themes

Adding themes to Bonfire is now simplified by using the centralized configuration:

1. Edit the `bonfire_ui_common.exs` configuration file
2. Add your theme to either `themes` (dark themes) or `themes_light` (light themes) list
3. Define your theme in the `theme_definitions` section

### Step 1: Add Theme Name to Lists

In `bonfire_ui_common.exs`, add your theme name to the appropriate list:

```elixir
themes: [
  "dark",
  "cyberpunk",
  ...,
  "mytheme-dark"  # Your custom dark theme
],
themes_light: [
  "light",
  "cupcake",
  ...,
  "mytheme"  # Your custom light theme
]
```

### Step 2: Define Your Custom Theme

Add your theme definition to the `theme_definitions` section in `bonfire_ui_common.exs`:

```elixir
theme_definitions: [
  %{
    name: "mytheme",
    default: false,
    prefersDark: false,
    colorScheme: "light",
    colors: %{
      primary: "#ff3e00",
      "primary-content": "#ffffff",
      secondary: "#d926aa",
      "secondary-content": "#ffffff",
      accent: "#1fb2a5",
      "accent-content": "#ffffff",
      neutral: "#191d24",
      "neutral-content": "#ffffff",
      "base-100": "#ffffff",
      "base-200": "#f9fafb",
      "base-300": "#f1f5f9",
      "base-content": "#1e293b",
      # ... other colors
    },
    radius: %{
      "selector": "1rem",
      "field": "0.5rem",
      "box": "0.75rem"
    },
    border: "1px",
    depth: %{
      "depth": 0.5,
      "noise": 0
    }
  }
]
```

## Theme Variables Reference

| Variable | Description |
|----------|-------------|
| `--color-base-100` | Main background color |
| `--color-base-200` | Slightly darker background |
| `--color-base-300` | Even darker background |
| `--color-base-content` | Text color on base backgrounds |
| `--color-primary` | Primary color |
| `--color-primary-content` | Text color on primary background |
| `--color-secondary` | Secondary color |
| `--color-secondary-content` | Text color on secondary background |
| `--color-accent` | Accent color |
| `--color-accent-content` | Text color on accent background |
| `--color-neutral` | Neutral color |
| `--color-neutral-content` | Text color on neutral background |
| `--color-info` | Information color (usually blue) |
| `--color-info-content` | Text color on info background |
| `--color-success` | Success color (usually green) |
| `--color-success-content` | Text color on success background |
| `--color-warning` | Warning color (usually yellow/orange) |
| `--color-warning-content` | Text color on warning background |
| `--color-error` | Error color (usually red) |
| `--color-error-content` | Text color on error background |

## API Reference

The ThemeManager module provides several utility functions:

```elixir
# Get JS script that initializes theme definitions
ThemeManager.theme_definitions_script()

# Get lists of themes
ThemeManager.all_themes()     # All themes
ThemeManager.dark_themes()    # Dark themes only
ThemeManager.light_themes()   # Light themes only

# Check theme properties
ThemeManager.theme_exists?("theme-name")     # Check if theme exists
ThemeManager.is_dark_theme?("theme-name")    # Check if theme is dark
ThemeManager.is_light_theme?("theme-name")   # Check if theme is light
```

## Synchronizing Themes

The theme lists are maintained in the `bonfire_ui_common.exs` config file. When you update these lists, you should run the synchronization task to update the CSS configuration:

```bash
mix bonfire.sync_themes
```

This task reads the `themes` and `themes_light` lists from the config and updates the DaisyUI theme configuration in `app.css` automatically.

## Example Custom Themes

The configuration already includes two custom themes:

### Bonfire Light Theme

```elixir
%{
  name: "bonfire",
  default: false,
  prefersDark: false,
  colorScheme: "light",
  colors: %{
    primary: "#ff3e00",
    "primary-content": "#ffffff",
    # ... other colors
  }
}
```

### Bonfire Dark Theme

```elixir
%{
  name: "bonfire-dark",
  default: false,
  prefersDark: true,
  colorScheme: "dark",
  colors: %{
    primary: "#ff3e00",
    "primary-content": "#ffffff",
    # ... other colors
  }
}
```

For more details, see the [DaisyUI theme documentation](https://daisyui.com/docs/themes/).
