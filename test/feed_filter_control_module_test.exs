defmodule Bonfire.UI.Common.FeedFilterControlModuleTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  alias Bonfire.UI.Common.FeedFilterControlModule

  defmodule StubControl do
    use Bonfire.UI.Common.Web, :stateless_component
    declare_feed_filter_control(:stub, filters: [stub_key: nil], after: :happening)
    def render(assigns), do: ~F"<div />"
  end

  defmodule StubControlAtEnd do
    use Bonfire.UI.Common.Web, :stateless_component
    declare_feed_filter_control(:stub_end, filters: [stub_end_key: []])
    def render(assigns), do: ~F"<div />"
  end

  defmodule NotAControl do
    def hello, do: :world
  end

  test "declared/1 returns what the control declared" do
    assert %{name: :stub, module: StubControl, filters: [stub_key: nil], after: :happening} =
             declared = FeedFilterControlModule.declared(StubControl)

    assert Map.has_key?(declared, :app)
    assert Map.has_key?(declared, :type)
  end

  test "an anchor is optional" do
    declared = FeedFilterControlModule.declared(StubControlAtEnd)
    assert %{name: :stub_end, filters: [stub_end_key: []]} = declared
    assert is_nil(declared[:after])
  end

  test "declared/1 is nil for a module that declares no control" do
    assert is_nil(FeedFilterControlModule.declared(NotAControl))
  end

  test "controls/1 keeps the given order and skips modules with no control" do
    assert [%{name: :stub_end}, %{name: :stub}] =
             FeedFilterControlModule.controls([StubControlAtEnd, NotAControl, StubControl])
  end
end
