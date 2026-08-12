defmodule Bonfire.UI.Common.LinkWidgetLiveTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Common.LinkWidgetLive

  test "active navigation receives a distinct surface, icon and label treatment" do
    widget = %{page: "home"}

    assert LinkWidgetLive.active?("home", widget, %{})
    assert LinkWidgetLive.active_icon_class("home", widget, %{}) == "text-primary"

    assert LinkWidgetLive.active_label_class("home", widget, %{}) ==
             "font-semibold text-base-content"
  end

  test "inactive navigation recedes without losing legibility" do
    widget = %{page: "home"}

    refute LinkWidgetLive.active?("notifications", widget, %{})

    assert LinkWidgetLive.active_link_class("notifications", widget, %{}) ==
             "hover:bg-base-content/5"

    assert LinkWidgetLive.active_icon_class("notifications", widget, %{}) == "text-muted"

    assert LinkWidgetLive.active_label_class("notifications", widget, %{}) ==
             "font-normal text-base-content/80"
  end
end
