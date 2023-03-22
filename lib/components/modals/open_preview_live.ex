defmodule Bonfire.UI.Common.OpenPreviewLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The title of the button used to open the modal. Only used if no `open_btn` slot is passed."
  prop(open_btn_text, :string, default: nil)

  @doc "The title of the modal. Only used if no `title` slot is passed."
  prop(title_text, :string, default: nil)

  @doc "The classes of the open button for the modal. Only used if no `open_btn` slot is passed."
  prop(open_btn_class, :css_class, default: "")

  prop(open_btn_wrapper_class, :css_class, default: "")

  @doc "Optional link on the open btn."
  prop(href, :string, default: nil)

  @doc """
  Additional assigns to pass on to the modal component
  """
  prop(modal_assigns, :any, default: [])

  prop(root_assigns, :any, default: [])

  prop(parent_id, :string, default: nil)

  @doc """
  Slot for the button that opens the modal
  """
  slot open_btn

  def handle_event("close", _, socket) do
    close()
    {:noreply, assign(socket, show: false)}
  end

  def close() do
    debug("close!")

    Bonfire.UI.Common.OpenModalLive.set(
      show: false,
      reusable_modal_component: Bonfire.UI.Common.PreviewContentLive,
      reusable_modal_id: "preview_content"
    )
  end
end
