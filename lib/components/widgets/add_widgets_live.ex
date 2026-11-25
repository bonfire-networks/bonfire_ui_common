defmodule Bonfire.UI.Common.AddWidgetsLive do
  @moduledoc """
  Edit mode's "Add to …" slot ending an area: a bottom sheet of the widgets that fit there and aren't shown. Shown only in edit mode (`widgets-editing`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The area the slot ends, eg. `:main` or `:sidebar`."
  prop area, :atom, required: true

  @doc "From `Bonfire.UI.Common.Widgets.place_assigns/3`."
  prop addable, :list, default: []

  prop class, :css_class, default: nil

  data title, :string, default: nil

  def render(assigns) do
    assigns
    |> assign(
      title: if(assigns.area == :main, do: l("Add to main area"), else: l("Add to sidebar"))
    )
    |> render_sface()
  end
end
