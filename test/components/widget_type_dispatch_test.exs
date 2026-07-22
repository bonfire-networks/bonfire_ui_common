defmodule Bonfire.UI.Common.WidgetTypeDispatchTest do
  @moduledoc """
  `WidgetLive` dispatches each sidebar widget on `@widget[:type]`. During the
  Surface→LiveView migration a widget module may be EITHER still-Surface OR
  converted (plain Phoenix), and EITHER stateless OR a live component — 4 kinds.
  Its `{#case}` must handle all four and render each the RIGHT way:

    * `Surface.Component`      → Surface `<StatelessComponent>`
    * `Surface.LiveComponent`  → Surface `<StatefulComponent>`
    * `Phoenix.Component`      → `dynamic_component` (plain function component)
    * `Phoenix.LiveComponent`  → `<.live_component>` (plain live component)

  Without the two `Phoenix.*` cases a converted widget falls to the `other`
  branch and renders `<!-- invalid widget -->` (silently vanishes).
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule SurfaceStatelessWidget do
    use Bonfire.UI.Common.Web, :stateless_component
    def render(assigns), do: ~F|<div data-id="surface-stateless">SURF_STATELESS_OK</div>|
  end

  defmodule SurfaceLiveWidget do
    use Bonfire.UI.Common.Web, :stateful_component
    def render(assigns), do: ~F|<div data-id="surface-live">SURF_LIVE_OK</div>|
  end

  defmodule PlainStatelessWidget do
    use Bonfire.UI.Common.Web, :function_component
    def render(assigns), do: ~H|<div data-id="plain-stateless">PLAIN_STATELESS_OK</div>|
  end

  defmodule PlainLiveWidget do
    use Bonfire.UI.Common.Web, :live_component
    def render(assigns), do: ~H|<div data-id="plain-live">PLAIN_LIVE_OK</div>|
  end

  defp widget_html(module, type) do
    render_component(&Bonfire.UI.Common.WidgetLive.render/1, %{
      widget: %{module: module, type: type, data: %{}},
      data: %{}
    })
  end

  test "Surface stateless widget renders" do
    assert widget_html(SurfaceStatelessWidget, Surface.Component) =~ "SURF_STATELESS_OK"
  end

  test "Surface live widget renders" do
    assert widget_html(SurfaceLiveWidget, Surface.LiveComponent) =~ "SURF_LIVE_OK"
  end

  test "converted plain function_component widget renders (Phoenix.Component)" do
    assert widget_html(PlainStatelessWidget, Phoenix.Component) =~ "PLAIN_STATELESS_OK"
  end

  test "converted plain live_component widget renders (Phoenix.LiveComponent)" do
    assert widget_html(PlainLiveWidget, Phoenix.LiveComponent) =~ "PLAIN_LIVE_OK"
  end

  # `component_type/1` is what the sidebar (and declare macros) use to set the
  # dispatch type from the module, so converting a widget flips it automatically —
  # reflecting on what Surface (`component_type/0`) and LiveView (`__live__/0`) expose.
  describe "component_type/1 derives the dispatch kind from the module" do
    test "Surface stateless → Surface.Component" do
      assert Bonfire.UI.Common.component_type(SurfaceStatelessWidget) == Surface.Component
    end

    test "Surface live → Surface.LiveComponent" do
      assert Bonfire.UI.Common.component_type(SurfaceLiveWidget) == Surface.LiveComponent
    end

    test "converted plain function component → Phoenix.Component" do
      assert Bonfire.UI.Common.component_type(PlainStatelessWidget) == Phoenix.Component
    end

    test "converted plain live component → Phoenix.LiveComponent" do
      assert Bonfire.UI.Common.component_type(PlainLiveWidget) == Phoenix.LiveComponent
    end
  end
end
