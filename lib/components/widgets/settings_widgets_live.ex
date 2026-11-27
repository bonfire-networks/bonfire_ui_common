defmodule Bonfire.UI.Common.SettingsWidgetsLive do
  @moduledoc """
  A page's widgets on a settings page, as that page's edit mode, always on: a column of tiles per area (eg. the dashboard's main area and sidebar), each ending with "Add to …", and the edit bar without Done. Only the tiles render, never the widgets' content. At instance scope, the main area's Add sheet ends with "Write your own widget" (`Bonfire.UI.Common.CustomWidgetFormLive`).

  The settings view sets up `widgets_editing` with `Bonfire.UI.Common.Widgets.LiveHandler.assign_settings_page/4` (which also handles the edits) and passes it as `widgets`.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.Widgets

  @doc "The page whose widgets these are, eg. `Bonfire.Web.Views.DashboardLive`."
  prop place, :atom, required: true

  @doc "The view's `widgets_editing`, from `Bonfire.UI.Common.Widgets.LiveHandler.assign_settings_page/4`."
  prop widgets, :map, default: %{}

  prop scope, :any, default: nil

  data areas, :list, default: []

  def render(assigns) do
    assigns
    # the main area first, whatever order the flavour's config lists them in
    |> assign(areas: Enum.sort_by(Widgets.areas(assigns.place), &(&1 != :main)))
    |> render_sface()
  end

  @doc "A list's id: the area's order key, which the edit events match it by."
  def list_id(place, area), do: to_string(Widgets.order_key({place, area}))

  @doc "An area's tiles, from `Widgets.place_assigns/4`."
  def area_widgets(widgets, :main), do: e(widgets, :main_widgets, [])
  def area_widgets(widgets, :sidebar), do: e(widgets, :sidebar_widgets, :users, :secondary, [])
  def area_widgets(_widgets, _area), do: []

  @doc "An area's heading, shown when the page has more than one area."
  def area_title(:main), do: l("Main area")
  def area_title(:sidebar), do: l("Sidebar")
  def area_title(area), do: to_string(area)
end
