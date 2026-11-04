defmodule Bonfire.UI.Common.TruncatableLive do
  @moduledoc """
  Clamps long content to a few lines, with Read more and Read less buttons, eg. for a post's body, a bio or a group's description.

  Give it the rendered `html` (eg. from `rich/2`) and an `id`, or a body of your own in the default slot. The body is the element marked `data-truncatable`: it is clamped while it has the `previewable_truncate` class (`app.css`), and this component's hook shows the buttons only when it overflows, so short content shows none. A body passed in the slot sets both itself, so it can leave out the class where it should be shown whole.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The dom id of the hook's element, so it must be unique on the page"
  prop id, :string, required: true

  @doc "The content to clamp, already rendered, used when no default slot is given"
  prop html, :any, default: nil

  @doc "Classes for the body rendered from `html`"
  prop class, :css_class, default: []

  @doc "Whether to include the Read more and Read less buttons"
  prop read_more, :boolean, default: true

  @doc "A body of the caller's own, marked `data-truncatable`, instead of `html`"
  slot default
end
