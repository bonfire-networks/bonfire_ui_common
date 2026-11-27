defmodule Bonfire.UI.Common.EditWidgetsBarLive do
  @moduledoc """
  Edit mode's bottom bar: "Drag to rearrange" or Undo for the widget just removed, and Done (unless `with_done` is false). Shown only in edit mode (`widgets-editing`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The widget just removed, as `%{id, name}`, for Undo."
  prop removed, :any, default: nil
  @doc "Whether it has Done: off for a page that is always editing (eg. a settings page)."
  prop with_done, :boolean, default: true

  @doc "Switches edit mode on, in the browser only (`data-widgets-editing`)."
  def edit_on,
    do:
      Phoenix.LiveView.JS.set_attribute({"data-widgets-editing", "true"},
        to: "[data-widgets-editable]"
      )

  @doc "Switches edit mode off."
  def edit_off,
    do:
      Phoenix.LiveView.JS.remove_attribute("data-widgets-editing", to: "[data-widgets-editable]")
end
