defmodule Bonfire.UI.Common.DesignSystem.IconButtonLive do
  @moduledoc """
  An icon-only button component with expanded touch targets.

  - **Touch target expansion**: Visual size can be smaller while maintaining 44px tap area
  - **aria-label required**: Icon buttons MUST have accessible labels
  - **Focus-visible**: Clear keyboard focus indicators
  - **Hover media queries**: Hover effects only on pointer devices

  ## Usage

      <.icon_button
        icon="ph:heart-duotone"
        aria_label="Like this post"
        variant="ghost"
      />

      <.icon_button
        icon="ph:x-duotone"
        aria_label="Close"
        size="sm"
        phx_click="close"
      />

  ## Touch Target Strategy

  The button uses `touch-target-expanded` which adds an invisible pseudo-element
  that extends the clickable area. This allows the visual button to appear small
  while maintaining adequate touch targets for mobile users.

  Visual sizes:
  - `xs` - 24px visual, 44px touch area
  - `sm` - 32px visual, 44px touch area
  - `md` - 40px visual, 44px touch area (default)
  - `lg` - 48px visual (already meets touch target)
  """

  use Phoenix.Component

  import Bonfire.UI.Common.DesignSystem.Helpers

  @doc "Iconify icon identifier (required unless using default slot)"
  attr :icon, :string, default: nil

  @doc "Accessible label (REQUIRED for icon buttons)"
  attr :aria_label, :string, required: true

  @doc "Button style variant"
  attr :variant, :string,
    default: "ghost",
    values: ~w(primary secondary ghost outline danger soft)

  @doc "Visual size of the button"
  attr :size, :string, default: "md", values: ~w(xs sm md lg)

  @doc "Show loading spinner instead of icon"
  attr :loading, :boolean, default: false

  @doc "Disable the button"
  attr :disabled, :boolean, default: false

  @doc "Button type attribute"
  attr :type, :string, default: "button", values: ~w(button submit reset)

  @doc "Toggle state for toggle buttons"
  attr :pressed, :boolean, default: nil

  @doc "Additional CSS classes"
  attr :class, :any, default: nil

  @doc "HTML id attribute"
  attr :id, :string, default: nil

  @doc "Phoenix click event (string event name or JS command struct)"
  attr :phx_click, :any, default: nil

  @doc "Phoenix click target"
  attr :phx_target, :any, default: nil

  @doc "Phoenix value attributes (map)"
  attr :phx_values, :map, default: %{}

  @doc "Tooltip text (shown on hover)"
  attr :tooltip, :string, default: nil

  @doc "Tooltip position"
  attr :tooltip_position, :string, default: "top", values: ~w(top bottom left right)

  @doc "Throttle clicks in milliseconds"
  attr :throttle, :integer, default: nil

  @doc "Debounce clicks in milliseconds"
  attr :debounce, :integer, default: nil

  @doc "Confirmation message"
  attr :confirm, :string, default: nil

  @doc "Additional HTML attributes"
  attr :rest, :global

  @doc "Custom icon content slot (overrides icon prop)"
  slot :inner_block

  def render(assigns) do
    {btn_size, icon_size, needs_expanded_target} = size_class(assigns.size)

    assigns =
      assigns
      |> assign(:btn_size, btn_size)
      |> assign(:icon_size, icon_size)
      |> assign(:needs_expanded_target, needs_expanded_target)

    ~H"""
    <button
      id={@id}
      type={@type}
      disabled={@disabled || @loading}
      aria-disabled={@disabled || @loading}
      aria-busy={@loading}
      aria-label={@aria_label}
      aria-pressed={@pressed}
      data-tip={@tooltip}
      phx-click={@phx_click}
      phx-target={@phx_target}
      data-confirm={@confirm}
      {rate_limit_attrs(@throttle, @debounce)}
      {phx_value_attrs(@phx_values)}
      {@rest}
      class={[
        "btn btn-circle",
        "inline-flex items-center justify-center",
        "focus-ring",
        "transition-interactive",
        "hover-scale",
        "active:scale-[0.95]",
        "disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none",
        "phx-click-loading:opacity-70 phx-click-loading:cursor-wait",
        variant_class(@variant),
        @btn_size,
        @class,
        @needs_expanded_target && "touch-target-expanded",
        @tooltip && "tooltip tooltip-#{@tooltip_position}",
        @loading && "cursor-wait"
      ]}
    >
      <%!-- Screen reader text --%>
      <span class="sr-only">{@aria_label}</span>

      <%!-- Loading spinner or icon with auto-loading support --%>
      <%= cond do %>
        <% @loading -> %>
          <span class={"loading loading-spinner #{@icon_size}"} aria-hidden="true"></span>
        <% has_slot_content?(@inner_block) -> %>
          <%!-- Custom slot content provided --%>
          <%= if @phx_click do %>
            <span
              class={"loading loading-spinner #{@icon_size} hidden phx-click-loading:inline"}
              aria-hidden="true"
            >
            </span>
            <span class="contents phx-click-loading:hidden" aria-hidden="true">
              <%= render_slot(@inner_block) %>
            </span>
          <% else %>
            <%= render_slot(@inner_block) %>
          <% end %>
        <% @icon -> %>
          <%!-- Icon prop provided --%>
          <%= if @phx_click do %>
            <span
              class={"loading loading-spinner #{@icon_size} hidden phx-click-loading:inline"}
              aria-hidden="true"
            >
            </span>
            <Iconify.iconify
              icon={@icon}
              class={"#{@icon_size} phx-click-loading:hidden"}
              aria-hidden="true"
            />
          <% else %>
            <Iconify.iconify icon={@icon} class={@icon_size} aria-hidden="true" />
          <% end %>
        <% true -> %>
          <%!-- Fallback: no icon or slot --%>
          <span class={"#{@icon_size}"} aria-hidden="true"></span>
      <% end %>
    </button>
    """
  end

  # Variant styles
  defp variant_class("primary"), do: "btn-primary"
  defp variant_class("secondary"), do: "btn-secondary"
  defp variant_class("ghost"), do: "btn-ghost"
  defp variant_class("outline"), do: "btn-outline"
  defp variant_class("danger"), do: "btn-error"
  defp variant_class("soft"), do: "btn-soft"

  # Visual size + icon size
  # All sizes use touch-target-expanded except lg which naturally meets 44px
  defp size_class("xs"), do: {"btn-xs w-6 h-6", "w-4 h-4", true}
  defp size_class("sm"), do: {"btn-sm w-8 h-8", "w-4 h-4", true}
  defp size_class("md"), do: {"w-10 h-10", "w-5 h-5", true}
  defp size_class("lg"), do: {"btn-lg w-12 h-12", "w-6 h-6", false}

  @doc "Get the icon size class for current size (useful for slot content)"
  def icon_size_class(size) do
    {_btn_size, icon_size, _needs_expanded} = size_class(size)
    icon_size
  end

  # Check if slot has content (handles Surface -> Phoenix component calls)
  defp has_slot_content?(nil), do: false
  defp has_slot_content?([]), do: false
  defp has_slot_content?(slot) when is_list(slot), do: true
  defp has_slot_content?(_), do: true
end
