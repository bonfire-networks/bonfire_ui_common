defmodule Bonfire.UI.Common.DesignSystem.ButtonLive do
  @moduledoc """
  A design system Button component for actions (not navigation).

  For navigation (links styled as buttons), use `LinkLive` with `variant` prop:

      <LinkLive to="/settings" variant="primary">Go to Settings</LinkLive>


  - **Touch targets**: Minimum 44px height for adequate tap targets (WCAG)
  - **Focus-visible**: Keyboard focus indicators only shown for keyboard navigation
  - **Hover media queries**: Hover effects only on devices with precise pointers
  - **Transitions**: Specific properties (never `transition-all`), 150ms duration
  - **Reduced motion**: Respects `prefers-reduced-motion` via CSS utilities

  ## Phoenix LiveView Best Practices

  - **Automatic loading states**: Uses `phx-click-loading:*` CSS variants for zero-JS loading feedback
  - **Throttling/Debouncing**: Built-in support via `throttle` and `debounce` props
  - **Confirmation dialogs**: Native browser confirm via `confirm` prop
  - **Form integration**: Proper `phx-submit-loading` states for submit buttons

  ## Usage Examples

  ### Basic Click Handler

      <.button variant="primary" phx_click="save">
        Save Changes
      </.button>

  ### With Automatic Loading State (Recommended)

      <.button variant="primary" phx_click="save" loading_text="Saving...">
        Save Changes
      </.button>

  ### With Throttling (Prevent Rapid Clicks)

      <.button phx_click="like" throttle={500}>
        Like
      </.button>

  ### With Confirmation

      <.button variant="danger" phx_click="delete" confirm="Are you sure?">
        Delete
      </.button>

  ### Form Submit Button

      <.button type="submit" loading_text="Submitting...">
        Submit Form
      </.button>

  ## Variants

  - `primary` - Main call-to-action (default)
  - `secondary` - Secondary actions
  - `ghost` - Minimal, transparent background
  - `outline` - Border only, transparent background
  - `danger` - Destructive actions (red)
  - `soft` - Subtle background tint

  ## Sizes

  - `xs` - Extra small (32px height, smaller touch target - use sparingly)
  - `sm` - Small (36px height)
  - `md` - Medium (44px height, default, meets touch target)
  - `lg` - Large (52px height)
  """

  use Phoenix.Component

  import Bonfire.UI.Common.DesignSystem.Helpers

  # ===== VISUAL PROPS =====

  @doc "Button style variant"
  attr :variant, :string,
    default: "primary",
    values: ~w(primary secondary ghost outline danger soft)

  @doc "Button size - md is recommended for touch targets"
  attr :size, :string, default: "md", values: ~w(xs sm md lg)

  @doc "Full width button"
  attr :full_width, :boolean, default: false

  @doc "Make button circular (for icon-only buttons)"
  attr :circle, :boolean, default: false

  @doc "Icon to show before text (iconify format)"
  attr :icon_left, :string, default: nil

  @doc "Icon to show after text (iconify format)"
  attr :icon_right, :string, default: nil

  @doc "Additional CSS classes"
  attr :class, :any, default: nil

  # ===== STATE PROPS =====

  @doc "Manually control loading state (prefer automatic via phx-click-loading)"
  attr :loading, :boolean, default: false

  @doc "Disable the button"
  attr :disabled, :boolean, default: false

  @doc "Text to show during loading (enables automatic loading indicator)"
  attr :loading_text, :string, default: nil

  # ===== HTML/FORM PROPS =====

  @doc "HTML id attribute"
  attr :id, :string, default: nil

  @doc "Button type attribute"
  attr :type, :string, default: "button", values: ~w(button submit reset)

  @doc "Accessible label (required for icon-only buttons)"
  attr :aria_label, :string, default: nil

  @doc "Form name for submit buttons"
  attr :form, :string, default: nil

  # ===== PHOENIX LIVEVIEW PROPS =====

  @doc "Phoenix click event name"
  attr :phx_click, :string, default: nil

  @doc "Phoenix click target (component or selector)"
  attr :phx_target, :any, default: nil

  @doc "Phoenix value attributes as map (becomes phx-value-*)"
  attr :phx_values, :map, default: %{}

  @doc "Throttle clicks in milliseconds (prevents rapid clicking)"
  attr :throttle, :integer, default: nil

  @doc "Debounce clicks in milliseconds (waits for pause)"
  attr :debounce, :integer, default: nil

  @doc "Confirmation message (shows browser confirm dialog)"
  attr :confirm, :string, default: nil

  # NOTE: For navigation, use LinkLive with variant prop instead:
  # <LinkLive to="/path" variant="primary">Go to Settings</LinkLive>

  # ===== OTHER =====

  @doc "Additional HTML attributes"
  attr :rest, :global

  @doc "Button content"
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <button
      id={@id}
      type={@type}
      form={@form}
      disabled={@disabled || @loading}
      aria-disabled={@disabled || @loading}
      aria-busy={@loading}
      aria-label={@aria_label}
      phx-click={@phx_click}
      phx-target={@phx_target}
      data-confirm={@confirm}
      {rate_limit_attrs(@throttle, @debounce)}
      {phx_value_attrs(@phx_values)}
      {@rest}
      class={[
        "btn group",
        "inline-flex items-center justify-center gap-2",
        "font-medium",
        "focus-ring",
        "transition-interactive",
        "hover-scale",
        "active:scale-[0.98]",
        "disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none",
        variant_class(@variant),
        size_class(@size),
        @class,
        @full_width && "w-full",
        @circle && "btn-circle aspect-square",
        @loading && "cursor-wait",
        has_auto_loading?(@phx_click, @type, @loading_text) &&
          "phx-click-loading:opacity-70 phx-click-loading:cursor-wait phx-submit-loading:opacity-70 phx-submit-loading:cursor-wait"
      ]}
    >
      <%!-- Loading state: show spinner when manually loading OR auto-loading --%>
      <%= if @loading do %>
        <span class="loading loading-spinner loading-sm" aria-hidden="true"></span>
      <% else %>
        <%= if has_auto_loading?(@phx_click, @type, @loading_text) do %>
          <%!-- Hidden by default, shown via phx-click-loading/phx-submit-loading CSS variants --%>
          <span class="loading loading-spinner loading-sm hidden phx-click-loading:inline phx-submit-loading:inline" aria-hidden="true"></span>
          <%= if @icon_left do %>
            <Iconify.iconify icon={@icon_left} class="w-5 h-5 shrink-0 phx-click-loading:hidden phx-submit-loading:hidden" aria-hidden="true" />
          <% end %>
        <% else %>
          <%= if @icon_left do %>
            <Iconify.iconify icon={@icon_left} class="w-5 h-5 shrink-0" aria-hidden="true" />
          <% end %>
        <% end %>
      <% end %>

      <%!-- Button content with loading text swap --%>
      <%= if has_auto_loading?(@phx_click, @type, @loading_text) do %>
        <span class={["truncate phx-click-loading:hidden phx-submit-loading:hidden", @circle && @aria_label && "sr-only"]}>
          <%= render_slot(@inner_block) %>
        </span>
        <span class="truncate hidden phx-click-loading:inline phx-submit-loading:inline">
          {@loading_text}
        </span>
      <% else %>
        <span class={["truncate", @circle && @aria_label && "sr-only"]}>
          <%= render_slot(@inner_block) %>
        </span>
      <% end %>

      <%!-- Right icon (hidden during loading) --%>
      <%= if @icon_right && !@loading do %>
        <span class={has_auto_loading?(@phx_click, @type, @loading_text) && "phx-click-loading:hidden phx-submit-loading:hidden"}>
          <Iconify.iconify icon={@icon_right} class="w-5 h-5 shrink-0" aria-hidden="true" />
        </span>
      <% end %>
    </button>
    """
  end

  # Variant styles using DaisyUI
  defp variant_class("primary"), do: "btn-primary"
  defp variant_class("secondary"), do: "btn-secondary"
  defp variant_class("ghost"), do: "btn-ghost"
  defp variant_class("outline"), do: "btn-outline"
  defp variant_class("danger"), do: "btn-error"
  defp variant_class("soft"), do: "btn-soft"

  # Size styles - md (44px) is the minimum recommended touch target
  defp size_class("xs"), do: "btn-xs h-8 min-h-8"
  defp size_class("sm"), do: "btn-sm h-9 min-h-9"
  defp size_class("md"), do: "h-11 min-h-11"
  defp size_class("lg"), do: "btn-lg h-13 min-h-13"

  # Check if this button will have automatic loading states
  defp has_auto_loading?(phx_click, type, loading_text) do
    (phx_click != nil or type == "submit") and loading_text != nil
  end
end
