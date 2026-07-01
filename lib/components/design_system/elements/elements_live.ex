defmodule Bonfire.UI.Common.DesignSystem.ElementsLive do
  @moduledoc """
  Small presentational design-system primitives (HEEx function components),
  bound to the theme tokens so they re-skin per `data-theme`.

  Exposed via `Bonfire.UI.Common.DesignSystem` as `<.card>`, `<.badge>`, `<.avatar>`.
  These reproduce the markup validated in the `/styleguide` (Jacobin design system).
  """
  use Phoenix.Component

  # ===================== CARD =====================

  @doc "Card surface: white (base-100), 0.7px secondary stroke, rounded-box."
  attr :padded, :boolean, default: true, doc: "Apply the standard card padding (p-card = 18px)"
  attr :tag, :string, default: "article"
  attr :class, :any, default: nil
  attr :rest, :global, doc: "extra attrs (e.g. data-component, id)"
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      class={[
        "bg-base-100 rounded-box border-hair border-secondary",
        @padded && "p-card",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  # ===================== BADGE =====================

  @doc "Outline pill badge (UMFRAGE / OFFEN): text-body uppercase, 0.7px border, rounded-selector."
  attr :variant, :string, default: "primary", values: ~w(primary success)
  attr :dot, :boolean, default: false, doc: "Show a leading status dot (e.g. OFFEN)"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-[6px] text-body uppercase leading-none px-3 py-[3px]",
      "rounded-selector border-hair",
      badge_variant_class(@variant),
      @class
    ]}>
      <span :if={@dot} class={["w-2 h-2 rounded-full", badge_dot_class(@variant)]}></span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_variant_class("primary"), do: "text-primary border-primary"
  defp badge_variant_class("success"), do: "text-success border-success"

  defp badge_dot_class("success"), do: "bg-success"
  defp badge_dot_class(_), do: "bg-primary"

  # ===================== AVATAR =====================

  @doc """
  Avatar: circle, 0.7px inset red ring, neutral placeholder. Size via `class`
  (default 35px). Falls back to a person icon when `src` is nil.
  """
  attr :src, :string, default: nil
  attr :alt, :string, default: nil
  attr :class, :any, default: "w-[35px] h-[35px]", doc: "size + shape (default 35px)"
  attr :icon_class, :string, default: "w-6 h-6"
  attr :rest, :global

  def avatar(assigns) do
    ~H"""
    <div
      class={[
        "rounded-full bg-base-300 border-hair border-primary overflow-hidden shrink-0",
        "flex items-end justify-center",
        @class
      ]}
      {@rest}
    >
      <img :if={@src} src={@src} alt={@alt} class="w-full h-full object-cover" />
      <Iconify.iconify
        :if={is_nil(@src)}
        icon="ph:user-fill"
        class={["text-base-content/40", @icon_class]}
        aria-hidden="true"
      />
    </div>
    """
  end
end
