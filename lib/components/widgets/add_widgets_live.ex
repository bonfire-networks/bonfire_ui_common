defmodule Bonfire.UI.Common.AddWidgetsLive do
  @moduledoc """
  Edit mode's "Add to …" slot ending an area: a bottom sheet of the widgets that fit there and aren't shown. Shown only in edit mode (`widgets-editing`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The area the slot ends, eg. `:main` or `:sidebar`."
  prop area, :atom, required: true

  @doc "From `Bonfire.UI.Common.Widgets.place_assigns/4` (on a settings page, its `widgets_editing`)."
  prop addable, :list, default: []

  prop class, :css_class, default: nil

  @doc "Anything after the widgets in the sheet, eg. the custom widget form on a settings page."
  slot default

  data title, :string, default: nil

  def render(assigns) do
    assigns
    |> assign(
      title: if(assigns.area == :main, do: l("Add to main area"), else: l("Add to sidebar"))
    )
    |> render_sface()
  end
end
