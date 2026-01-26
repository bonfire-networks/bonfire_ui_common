defmodule Bonfire.UI.Common.DesignSystem do
  @moduledoc """
  Bonfire Design System

  ## Core Principles

  Every component in this design system follows these principles:

  ### 1. No Layout Shift
  - Use fixed dimensions where possible
  - `font-variant-numeric: tabular-nums` for changing numbers
  - No font weight changes on hover/selected states

  ### 2. Touch-First, Hover-Enhanced
  - Minimum 44px touch targets (or `touch-target-expanded` for smaller visuals)
  - Hover effects only on `@media (hover: hover) and (pointer: fine)`
  - Active states for touch devices

  ### 3. Keyboard Navigation
  - All interactive elements are focusable
  - `focus-visible` for keyboard-only focus indicators
  - Proper tab order and focus management

  ### 4. Accessibility by Default
  - `prefers-reduced-motion` support built into CSS
  - Required `aria-label` on icon-only buttons
  - `aria-invalid` and `aria-describedby` on form inputs
  - Semantic HTML elements

  ### 5. Speed Over Delight
  - Transitions are 150ms (fast but perceivable)
  - No animation on frequently-used interactions
  - Specific transition properties (never `transition-all`)

  ## Available Components

  ### Buttons
  - `Bonfire.UI.Common.DesignSystem.ButtonLive` - Full-featured button with variants
  - `Bonfire.UI.Common.DesignSystem.IconButtonLive` - Icon-only button with expanded touch target

  ## CSS Utilities

  These utility classes are defined in `app.css` and used throughout:

  - `.focus-ring` - Keyboard-only focus indicator
  - `.touch-target` - Minimum 44x44px dimensions
  - `.touch-target-expanded` - Invisible expanded touch area
  - `.transition-interactive` - Standard interactive transition
  - `.hover-scale` - Scale on hover (pointer devices only)
  - `.hover-lift` - Lift on hover (pointer devices only)

  ## Z-Index Scale

  Use semantic z-index values instead of arbitrary numbers:

  ```
  z-dropdown: 100
  z-sticky: 200
  z-fixed: 300
  z-modal-backdrop: 400
  z-modal: 500
  z-popover: 600
  z-tooltip: 700
  z-toast: 800
  ```

  ## Usage Example

      alias Bonfire.UI.Common.DesignSystem.{ButtonLive, IconButtonLive}

      <ButtonLive variant="primary" size="md" phx_click="save">
        Save Changes
      </ButtonLive>

      <IconButtonLive
        icon="ph:heart-duotone"
        aria_label="Like"
        variant="ghost"
        phx_click="like"
      />
  """

  # Re-export components for convenient aliasing
  defdelegate button(assigns), to: Bonfire.UI.Common.DesignSystem.ButtonLive, as: :render
  defdelegate icon_button(assigns), to: Bonfire.UI.Common.DesignSystem.IconButtonLive, as: :render
end
