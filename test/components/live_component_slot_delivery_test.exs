defmodule Bonfire.UI.Common.LiveComponentSlotDeliveryTest do
  @moduledoc """
  Locks in that Phoenix's `<.live_component>` forwards BOTH default and named
  slot entries to the component (as assigns), so the component can `render_slot`
  them.

  This is the premise the surface_eject dynamic-dispatch conversion relies on:
  Surface's `<StatefulComponent module={M}><:slot>…` becomes plain
  `<.live_component module={M}><:slot>…`, and (if this holds) the whole
  `live_component_slot_entrypoints` indirection — plus the `open_modal/1` /
  `new_group/1` landing pads — is unnecessary, since `<.live_component>` accepts
  the slots directly.
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule SlotSink do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        default:[{render_slot(@inner_block)}]
        named:[{render_slot(@extra)}]
      </div>
      """
    end
  end

  defmodule Caller do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <.live_component module={SlotSink} id="sink">
        DEFAULT_CONTENT
        <:extra>NAMED_CONTENT</:extra>
      </.live_component>
      """
    end
  end

  test "<.live_component> delivers both default and named slots to the component" do
    html = render_component(&Caller.render/1, %{})

    assert html =~ "DEFAULT_CONTENT"
    assert html =~ "NAMED_CONTENT"
  end
end
