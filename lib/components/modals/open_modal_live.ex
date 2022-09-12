defmodule Bonfire.UI.Common.OpenModalLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.UI.Common.Web, :stateful_component

  @doc "The title of the button used to open the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_text, :string, default: nil

  @doc "The title of the modal. Only used if no `title` slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: "font-bold text-base"

  @doc "The classes of the open button for the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_class, :css_class, default: ""

  prop open_btn_opts, :any, default: []

  @doc "Optional link on the open btn."
  prop href, :string, default: nil

  @doc "Optional JS hook on the open btn."
  prop open_btn_hook, :string, default: nil

  @doc "The classes of the close/cancel button on the modal. Only used if no `close_btn` slot is passed."
  prop cancel_btn_class, :css_class, default: "btn btn-outline btn-sm normal-case"

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :any, default: []

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  @doc "The classes of the title of the modal"
  prop reusable_modal_component, :atom, default: Bonfire.UI.Common.ReusableModalLive

  @doc "The ID of this instance of the modal"
  prop reusable_modal_id, :string, default: "modal"

  @doc """
  Additional assigns to pass on to the modal component
  """
  prop modal_assigns, :any, default: []

  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []

  prop autocomplete, :list, default: []

  @doc """
  Slots for the contents of the modal, title, buttons...
  """
  slot default, args: [:autocomplete]

  slot open_btn
  slot action_btns
  slot cancel_btn
  slot title

  def open() do
    debug("open!")
    set(show: true)
  end

  def close() do
    debug("close!")
    set(show: false)
  end

  def set(assigns) do
    maybe_send_update(
      e(
        assigns,
        :reusable_modal_component,
        Bonfire.UI.Common.ReusableModalLive
      ),
      e(assigns, :reusable_modal_id, "modal"),
      assigns
    )
  end

  # Default event handlers

  def handle_event("open", _, socket) do
    debug("open!")

    socket =
      assign(socket,
        show: true
      )

    # copy all of this component's assigns to the reusable modal (including slots!)
    set(socket.assigns)

    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    close()
    {:noreply, socket}
  end

  def handle_event(action, attrs, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_event(
        action,
        attrs,
        socket,
        __MODULE__
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
