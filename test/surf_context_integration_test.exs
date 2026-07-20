defmodule Bonfire.UI.Common.SurfContextIntegration.ChildLive do
  # the real Bonfire macro — post-wiring this compiles ~H through SurfContext
  use Bonfire.UI.Common.Web, :function_component

  def child(assigns) do
    ~H"""
    <span data-role="ctx-child">who:{@__context__[:who]} user:{current_user_id(@__context__)}</span>
    """
  end
end

defmodule Bonfire.UI.Common.SurfContextIntegration.ParentLive do
  use Bonfire.UI.Common.Web, :function_component

  alias Bonfire.UI.Common.SurfContextIntegration.ChildLive

  def parent(assigns) do
    ~H"""
    <div data-role="ctx-parent"><ChildLive.child /></div>
    """
  end
end

defmodule Bonfire.UI.Common.SurfContextIntegration.ViewLive do
  # the real Bonfire LiveView macro — its render/1 must thread context too
  use Bonfire.UI.Common.Web, :live_view

  alias Bonfire.UI.Common.SurfContextIntegration.ChildLive

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    ~H"""
    <main data-role="ctx-view"><ChildLive.child /></main>
    """
  end
end

defmodule Bonfire.UI.Common.SurfContextIntegration.CardLive do
  # the real Bonfire stateful macro, receives context as a passed assign
  # (`<.live_component>` call sites are threaded; not on the skip list)
  use Bonfire.UI.Common.Web, :live_component

  def render(assigns) do
    ~H"""
    <div data-role="ctx-lc">lc:{@__context__[:who]}</div>
    """
  end
end

defmodule Bonfire.UI.Common.SurfContextIntegrationTest do
  @moduledoc """
  Integration: Bonfire's Web macros (`:function_component`) compile templates
  through SurfContext — context threads implicitly through component call
  sites, and Bonfire's own read helpers (`current_user_id(@__context__)` — the
  dominant template pattern) work unchanged.
  """
  use ExUnit.Case, async: true

  # required by Phoenix.LiveViewTest.render_component/2
  @endpoint Bonfire.Web.Endpoint

  alias Bonfire.UI.Common.SurfContextIntegration.ParentLive

  # canonical example ULID (valid Crockford), so current_user_id/1 accepts it
  @user_id "01ARZ3NDEKTSV4RRFFQ69G5FAV"

  defp render(fun, assigns) do
    fun.(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
  end

  test "context threads implicitly through Bonfire Web-macro components" do
    assigns =
      SurfContext.put(%{__changed__: nil}, who: "bonfire", current_user_id: @user_id)

    html = render(&ParentLive.parent/1, assigns)

    assert html =~ "who:bonfire"
    assert html =~ "user:#{@user_id}"
  end

  test "a Bonfire :live_view macro view threads context from its render/1" do
    assigns =
      SurfContext.put(%{__changed__: nil}, who: "view", current_user_id: @user_id)

    html = render(&Bonfire.UI.Common.SurfContextIntegration.ViewLive.render/1, assigns)

    assert html =~ "data-role=\"ctx-view\""
    assert html =~ "who:view"
  end

  test "a Bonfire :live_component macro LC receives threaded context" do
    import Phoenix.LiveViewTest

    # render_component runs the LC lifecycle with the given assigns —
    # __context__ here is exactly what a threaded `<.live_component>` call
    # site passes (live_component is deliberately NOT skip-listed)
    html =
      render_component(Bonfire.UI.Common.SurfContextIntegration.CardLive,
        id: "lc1",
        __context__: %{who: "stateful"}
      )

    assert html =~ "lc:stateful"
  end

  test "unthreaded render is nil-safe (auto-declared context attr default)" do
    # child rendered without any context put — auto-declared nil default,
    # nil-tolerant reads → renders empty values instead of raising
    html =
      render(
        &Bonfire.UI.Common.SurfContextIntegration.ChildLive.child/1,
        %{__changed__: nil, __context__: nil}
      )

    assert html =~ "data-role=\"ctx-child\""
  end
end
