defmodule Bonfire.UI.Common.OpenModalLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.ReusableModalLive

  @doc "The title of the button used to open the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_text, :string, default: nil

  @doc "The title of the modal. Only used if no `title` slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: "font-bold text-base flex-1"

  @doc "The classes of the open button for the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_class, :css_class, default: ""

  prop open_btn_wrapper_class, :css_class, default: ""

  prop open_btn_opts, :any, default: []

  @doc "Optional link on the open btn."
  prop href, :string, default: nil

  @doc "Optional JS hook on the open btn."
  prop open_btn_hook, :string, default: nil

  prop click_open_event, :string, default: "open"

  @doc "The classes of the modal wrapper."
  prop wrapper_class, :css_class, default: nil

  @doc "The classes of the modal"
  prop modal_class, :css_class, default: "max-h-[100%]"

  @doc "The classes around the action/submit button(s) on the modal"
  prop action_btns_wrapper_class, :css_class, default: nil

  @doc "The classes of the close/cancel button on the modal. Only used if no `close_btn` slot is passed."
  prop cancel_btn_class, :css_class, default: "btn btn-ghost rounded btn-sm normal-case"

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :any, default: []

  @doc "Optional prop to hide the header at the top of the modal"
  prop no_header, :boolean, default: false

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  prop enable_fallback, :boolean, default: false

  @doc "The classes of the title of the modal"
  prop reusable_modal_component, :atom, default: ReusableModalLive

  @doc "The ID of this instance of the modal"
  prop reusable_modal_id, :string, default: "modal"

  @doc """
  Additional assigns to pass on to the modal component
  """
  prop modal_assigns, :any, default: []

  @doc """
  Additional assigns to send up to the top-level LiveView
  """
  prop root_assigns, :any, default: []

  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []

  prop autocomplete, :list, default: []

  @doc """
  Slot for the contents of the modal, title, buttons...
  """
  slot default, args: [:autocomplete]
  slot title
  slot action_btns
  slot cancel_btn

  @doc """
  Slot for the button that opens the modal
  """
  slot open_btn

  def open() do
    debug("open!")
    set(show: true)
  end

  def close() do
    debug("close!")
    set([show: false] ++ ReusableModalLive.default_assigns())
  end

  def set(assigns) do
    maybe_send_update(
      e(
        assigns,
        :reusable_modal_component,
        ReusableModalLive
      ),
      e(assigns, :reusable_modal_id, "modal"),
      assigns
    )

    # case assigns[:root_assigns] do
    #   root_assigns when is_list(root_assigns) and root_assigns !=[] ->
    #     send_self(assigns[:root_assigns])

    #   _ -> nil
    # end
  end

  # Default event handlers

  def do_handle_event("open", _, socket) do
    debug("open!")

    socket =
      assign(socket,
        show: true
      )

    # copy all of this component's assigns to the reusable modal (including slots!)
    set(socket.assigns)

    {:noreply, socket}
  end

  def do_handle_event("close", _, socket) do
    close()
    {:noreply, socket}
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__,
          &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
