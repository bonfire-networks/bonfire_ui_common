defmodule Bonfire.UI.Common.RenderErrorHandlingTest do
  @moduledoc """
  Every component's `render/1` is wrapped by `undead_render`: a component that fails degrades to an inline error placeholder, the page around it still renders, and the exception that caused it is reported so it can be diagnosed.
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  defmodule Exploding do
    use Bonfire.UI.Common.Web, :stateless_component

    def render(_assigns), do: raise("KABOOM_FROM_RENDER")
  end

  test "a component that raises renders the error placeholder rather than breaking its parent" do
    assert render_component(&Exploding.render/1, %{}) =~ ~s(data-role="render_error")
  end

  test "the placeholder shows a generic message rather than the raw exception" do
    html = render_component(&Exploding.render/1, %{})

    assert html =~ "Sorry, the app encountered an unexpected error"
    refute html =~ "KABOOM_FROM_RENDER"
  end

  test "the exception that broke the render is logged" do
    assert capture_log(fn -> render_component(&Exploding.render/1, %{}) end) =~
             "KABOOM_FROM_RENDER"
  end
end
