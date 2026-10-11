defmodule Bonfire.UI.Common.WidgetsLiveTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Common.WidgetsLive

  doctest Bonfire.UI.Common.WidgetsLive

  test "a widget added after the order was saved goes last, rather than taking a saved position" do
    saved = %{Widget.C => 0, Widget.A => 1}

    assert [Widget.C, Widget.A, Widget.B] =
             [%{module: Widget.A}, %{module: Widget.B}, %{module: Widget.C}]
             |> WidgetsLive.sort_by_saved_order(saved, &WidgetsLive.order_key/1)
             |> Enum.map(fn {widget, _index} -> widget.module end)
  end

  test "a widget with a page is filed under its page, the same way for sorting and saving" do
    saved = %{home: 0}

    assert [{%{page: "home"}, 1}, {%{module: Widget.A}, 0}] =
             WidgetsLive.sort_by_saved_order(
               [%{module: Widget.A}, %{page: "home", module: Widget.H}],
               saved,
               &WidgetsLive.order_key/1
             )
  end
end
