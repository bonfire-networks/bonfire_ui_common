defmodule Bonfire.UI.Common.OpenExpanderLive do
  @moduledoc """
  Accordion-style variant of `Bonfire.UI.Common.OpenPreviewLive`: a stateless wrapper that preconfigures the stateful `Bonfire.UI.Common.OpenModalLive` in `:expander` mode, so the content expands inline (below the trigger) instead of opening the modal singleton.

  Because the content is gated on the expander's open state, a stateful `modal_component` only mounts when first expanded (and unmounts on collapse) — useful when the child does expensive work in `update/2` and the parent is a stateless component that can't hold the open/closed state itself.

  Accepts the same `modal_assigns` shape as `OpenModalLive` (`modal_component`, `modal_component_stateful?`, plus assigns for the child component), so existing modal payloads can be reused as-is.

  The trigger renders as a full-width disclosure row with a caret that rotates when open; pass the row's inner content (icon, label, badges...) via the `open_btn` slot, or just `open_btn_text`.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The label of the trigger row. Only used if no `open_btn` slot is passed."
  prop(open_btn_text, :string, default: nil)

  @doc "The classes of the trigger row (laid out as a flex row: slot content, then the caret)"
  prop(
    open_btn_class,
    :css_class,
    default:
      "p-3 w-full text-sm text-base-content/80 flex items-center gap-2 hover:bg-base-content/5 hover:text-base-content transition-colors"
  )

  prop(open_btn_wrapper_class, :css_class, default: "")

  @doc "The classes of the caret icon (a `rotate-90` is added when open)"
  prop(caret_class, :css_class, default: "w-4 h-4 text-base-content/50 transition-transform")

  @doc "The classes of the inline content container"
  prop(expander_wrapper_class, :css_class, default: "border-t-hair border-secondary")

  @doc """
  Additional assigns to pass on to the expanded component (same shape as `OpenModalLive`'s `modal_assigns`)
  """
  prop(modal_assigns, :any, default: [])

  prop(parent_id, :string, default: nil)

  @doc """
  Slot for the inner content of the trigger row (icon, label, badges...). Receives `show` in case it wants to reflect the open/closed state beyond the built-in caret.
  """
  slot(open_btn, arg: [show: :boolean])

  @doc """
  Slot for inline content, as an alternative to passing a component via `modal_assigns`
  """
  slot(default, arg: [autocomplete: :list, value: :any])
end
