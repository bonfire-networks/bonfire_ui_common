# Bonfire Design System


## Quick Start

```elixir
# Import in your module
import Bonfire.UI.Common.DesignSystem.ButtonLive
import Bonfire.UI.Common.DesignSystem.IconButtonLive
```

```heex
<.render variant="primary" phx_click="save" loading_text="Saving...">
  Save Changes
</.render>

<%!-- Or use via the DesignSystem module --%>
<Bonfire.UI.Common.DesignSystem.button variant="primary" phx_click="save">
  Save Changes
</Bonfire.UI.Common.DesignSystem.button>

<Bonfire.UI.Common.DesignSystem.icon_button icon="ph:heart-duotone" aria_label="Like" phx_click="like" />
```

## Core Principles

| Principle | Implementation |
|-----------|----------------|
| No layout shift | Fixed dimensions, `tabular-nums` for numbers |
| Touch-first | 44px minimum targets, `touch-target-expanded` |
| Hover-enhanced | `@media (hover: hover)` for hover effects |
| Keyboard nav | `focus-visible` indicators, proper tab order |
| Accessibility | `aria-*` attributes, reduced motion support |
| Speed over delight | 150ms transitions, specific properties |
| Zero-JS loading | `phx-click-loading:*` CSS variants |

## Phoenix LiveView Integration

All components are optimized for Phoenix LiveView with automatic loading states, throttling, and navigation support.

### Automatic Loading States (Recommended)

Use `loading_text` to enable zero-JavaScript loading feedback via CSS:

```heex
<.render phx_click="save" loading_text="Saving...">
  Save Changes
</.render>
```

When clicked:
1. Button shows spinner + "Saving..." text automatically
2. Button becomes visually disabled (opacity, cursor)
3. Reverts when server responds

This uses `phx-click-loading:*` CSS variants - no manual state management needed!

### Throttling & Debouncing

Prevent rapid clicks or wait for typing pauses:

```heex
<%!-- Prevent rapid double-clicks --%>
<.render phx_click="like" throttle={500}>Like</.render>

<%!-- Wait for user to stop typing --%>
<.render phx_click="search" debounce={300}>Search</.render>
```

### Confirmation Dialogs

Native browser confirm before dangerous actions:

```heex
<.render variant="danger" phx_click="delete" confirm="Delete this permanently?">
  Delete
</.render>
```

### LiveView Navigation

For navigation (links styled as buttons), use `LinkLive` with `variant` prop instead of ButtonLive:

```heex
<%!-- Full navigation (replaces history) --%>
<LinkLive to="/settings" variant="primary">Settings</LinkLive>

<%!-- Patch (preserves LiveView state) --%>
<LinkLive patch="/users?page=2" variant="ghost">Next Page</LinkLive>
```

**Note:** Buttons are for actions, links are for navigation. This separation improves semantics and accessibility.

### Form Submit Buttons

For forms, use `type="submit"` with `loading_text`:

```heex
<.form for={@form} phx-submit="create_user">
  <%!-- form fields --%>
  <.render type="submit" loading_text="Creating...">
    Create User
  </.render>
</.form>
```

## Components

### ButtonLive

Full-featured button with variants, sizes, and LiveView integration.

```heex
<%!-- Import the module first --%>
import Bonfire.UI.Common.DesignSystem.ButtonLive

<.render
  variant="primary"           # primary|secondary|ghost|outline|danger|soft
  size="md"                   # xs|sm|md|lg (md = 44px, recommended)
  loading={false}             # Manual loading state
  loading_text="Saving..."    # Enable auto-loading with this text
  disabled={false}
  full_width={false}
  icon_left="ph:check"        # Icon before text
  icon_right="ph:arrow-right"
  phx_click="save"
  phx_values={%{id: @id}}
  throttle={500}              # Rate limit in ms
  confirm="Are you sure?"     # Browser confirm dialog
>
  Button Text
</.render>
```

**Note:** For navigation, use `LinkLive` with `variant` prop instead.

### IconButtonLive

Icon-only button with expanded touch target and LiveView integration.

```heex
<%!-- Import the module first --%>
import Bonfire.UI.Common.DesignSystem.IconButtonLive

<.render
  icon="ph:heart-duotone"     # Required (unless using slot)
  aria_label="Like this post" # Required for accessibility
  variant="ghost"
  size="md"
  pressed={@liked}            # For toggle buttons
  tooltip="Like"
  tooltip_position="bottom"
  phx_click="like"
  throttle={500}              # Rate limit in ms
  confirm="Unlike this?"      # Browser confirm dialog
/>
```

## CSS Utilities

Available in `app.css`:

```css
.focus-ring          /* Keyboard-only focus indicator */
.touch-target        /* 44x44px minimum dimensions */
.touch-target-expanded /* Invisible expanded touch area */
.transition-interactive /* 150ms transform/opacity/colors */
.hover-scale         /* scale(1.02) on hover (pointer only) */
.hover-lift          /* translateY(-2px) on hover */
```

## Z-Index Scale

Use semantic values instead of arbitrary numbers:

| Token | Value | Use Case |
|-------|-------|----------|
| `z-dropdown` | 100 | Dropdown menus |
| `z-sticky` | 200 | Sticky headers |
| `z-fixed` | 300 | Fixed elements |
| `z-modal-backdrop` | 400 | Modal backgrounds |
| `z-modal` | 500 | Modal dialogs |
| `z-popover` | 600 | Popovers |
| `z-tooltip` | 700 | Tooltips |
| `z-toast` | 800 | Toast notifications |

## Accessibility Checklist

When creating new components:

- [ ] Touch targets are 44px minimum (or use `touch-target-expanded`)
- [ ] Icon-only buttons have `aria-label`
- [ ] Form inputs have `aria-invalid` and `aria-describedby`
- [ ] Toggle buttons have `aria-pressed`
- [ ] Loading states have `aria-busy`
- [ ] Decorative icons have `aria-hidden="true"`
- [ ] Focus states use `focus-ring` class
- [ ] Animations respect `prefers-reduced-motion`

## Adding New Components

1. Create folder: `design_system/component_name/`
2. Create module: `component_name_live.ex` with props and docs
3. Create template: `component_name_live.sface`
4. Add to `design_system.ex` exports
5. Verify against accessibility checklist
