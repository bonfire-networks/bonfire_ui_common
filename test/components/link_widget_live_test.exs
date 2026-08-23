defmodule Bonfire.UI.Common.LinkWidgetLiveTest do
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui

  alias Bonfire.UI.Common.LinkWidgetLive

  # the class helpers take the boolean `active?/3` returns, rather than recomputing it per styled part, the template evaluates it once per nav item (see the note in `LinkWidgetLive`)
  test "active navigation receives a distinct surface, icon and label treatment" do
    widget = %{page: "home"}
    active? = LinkWidgetLive.active?("home", widget, %{})

    assert active?
    assert LinkWidgetLive.active_link_class(active?) == ""
    assert LinkWidgetLive.active_icon_class(active?) == "text-primary"
    assert LinkWidgetLive.active_label_class(active?) == "font-semibold text-base-content"
  end

  test "inactive navigation recedes without losing legibility" do
    widget = %{page: "home"}
    active? = LinkWidgetLive.active?("notifications", widget, %{})

    refute active?
    assert LinkWidgetLive.active_link_class(active?) == "hover:bg-base-content/5"
    assert LinkWidgetLive.active_icon_class(active?) == "text-muted"
    assert LinkWidgetLive.active_label_class(active?) == "font-normal text-base-content/80"
  end
end
