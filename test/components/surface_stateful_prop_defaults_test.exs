defmodule Bonfire.UI.Common.SurfaceStatefulPropDefaultsTest do
  @moduledoc """
  A CONVERTED (plain HEEx) parent renders a still-Surface `:stateful_component`
  via `<.live_component module={M} id={..}>`. Surface injects a component's prop
  defaults at the CALL SITE (in the parent's `~F`) — its `mount` only assigns
  DATA defaults and its `update` wrapper only threads private/context assigns, so
  a plain-HEEx caller skips prop defaults entirely.

  A Surface `LiveComponent` with a custom `update/2` that ROUTES on a defaulted
  prop then falls through to a clause that never `assign`s the incoming assigns —
  dropping even the framework-provided `id` — and its template hits `@id` →
  `KeyError`. (This is the FeedLive regression: it routes on `feed`/`loading`
  defaults; with none present it hits its `do_update(_assigns, socket)` catch-all
  which returns the socket without assigning `id`.)

  The stateful update wrapper (`__live_update_before_compile__` in
  `Bonfire.UI.Common.Web`) fills the component's own `__props__` defaults before
  its `update/2`, restoring Surface's call-site semantics regardless of caller.
  Mirrors the stateless callee shim (`apply_surface_prop_defaults`).
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule StatefulCallee do
    use Bonfire.UI.Common.Web, :stateful_component

    prop mode, :atom, default: :ready

    # Only re-assigns the incoming assigns (incl. the framework `id`) when the
    # defaulted prop is present — like FeedLive routing on `feed`/`loading`.
    def update(%{mode: :ready} = assigns, socket) do
      {:ok, assign(socket, assigns)}
    end

    # Catch-all that forgets to re-assign: `id` is lost here (the FeedLive bug).
    def update(_assigns, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~F"<div id={@id}>mode:{@mode}</div>"
    end
  end

  test "a Surface stateful component routing its update on a defaulted prop keeps @id when rendered via plain live_component (default omitted)" do
    html = render_component(StatefulCallee, %{id: "sc1"})

    assert html =~ ~s(id="sc1")
    assert html =~ "mode:ready"
  end
end
