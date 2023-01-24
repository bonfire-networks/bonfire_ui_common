defmodule Bonfire.UI.Common.ReusableModalLive do
  use Bonfire.UI.Common.Web, :stateful_component

  @moduledoc """
  The classic **modal**
  """

  @modal_class "max-h-[100%]"
  @form_id "reusable_modal_form"

  # make sure to keep these and the Surface props in sync
  @default_assigns [
    title_text: nil,
    title_class: nil,
    modal_class: @modal_class,
    cancel_btn_class: nil,
    show: false,
    form_opts: [],
    form_id: @form_id,
    no_actions: false,
    no_header: false,
    opts: [],
    autocomplete: [],
    default: nil,
    open_btn: nil,
    action_btns: nil,
    cancel_btn: nil,
    title: nil
  ]

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string, default: nil

  @doc "If the modal is a preview of an image, set this to true."
  prop image_preview, :boolean, default: false

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: nil

  @doc "The classes of the modal."
  prop modal_class, :css_class, default: @modal_class

  @doc "The classes of the modal wrapper."
  prop wrapper_class, :css_class, default: nil

  @doc "The classes around the action/submit button(s) on the modal"
  prop action_btns_wrapper_class, :css_class, default: nil

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :css_class, default: nil

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :any, default: []

  @doc "The ID of the form to submit"
  prop form_id, :string, default: @form_id

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  @doc "Optional prop to hide the header at the top of the modal"
  prop no_header, :boolean, default: false

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

  def mount(socket) do
    # debug("mounting")
    # need this because ReusableModalLive used in Phoenix HEEX layout doesn't set Surface defaults
    {:ok,
     socket
     |> assign(default_assigns())}
  end

  def default_assigns do
    @default_assigns
  end

  def do_handle_event("close", _, socket) do
    # debug("reset all assigns to defaults so they don't accidentally get re-used in a different modal")
    {:noreply, assign(socket, [show: false] ++ default_assigns())}
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
