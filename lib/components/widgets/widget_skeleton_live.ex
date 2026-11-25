defmodule Bonfire.UI.Common.WidgetSkeletonLive do
  @moduledoc """
  A grey, static sketch of a widget's shape for edit mode's tiles, named by `skeleton:` in `declare_widget` (default `:text`). Static on purpose: daisyUI's `skeleton` pulses, which reads as loading.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @shapes [:text, :feed, :chips, :links, :people, :list, :status, :poll, :cards, :stats]

  @doc "One of #{inspect(@shapes)}."
  prop shape, :atom, default: :text

  def shapes, do: @shapes

  def render(assigns) do
    assigns
    |> assign(shape: if(assigns.shape in @shapes, do: assigns.shape, else: :text))
    |> render_sface()
  end
end
