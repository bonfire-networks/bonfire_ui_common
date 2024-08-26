defmodule Bonfire.UI.Common.ReusableModalLive do
  use Bonfire.UI.Common.Web, :stateful_component

  @moduledoc """
  The classic **modal**
  """

  # make sure to keep these and the Surface props in sync
  @default_assigns [
    title_text: nil,
    title_class: nil,
    modal_class: "",
    cancel_btn_class: nil,
    show: false,
    form_opts: %{},
    no_actions: false,
    no_header: false,
    no_backdrop: false,
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
  prop modal_class, :css_class, default: ""

  @doc "The classes of the modal wrapper."
  prop wrapper_class, :css_class, default: nil

  @doc "The classes around the action/submit button(s) on the modal"
  prop action_btns_wrapper_class, :css_class, default: nil

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :css_class, default: nil

  prop cancel_label, :string, default: nil

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  # prop no_form, :boolean, default: false

  prop form_opts, :map, default: %{}

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  @doc "Optional prop to hide the header at the top of the modal"
  prop no_header, :boolean, default: false

  prop no_backdrop, :boolean, default: false

  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []

  prop autocomplete, :list, default: []

  data value, :any, default: nil

  @doc """
  Slots for the contents of the modal, title, buttons...
  """
  slot open_btn, arg: [autocomplete: :list, value: :any]
  slot action_btns
  slot cancel_btn
  slot title
  slot default, arg: [autocomplete: :list, value: :any]

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

  def handle_event("close-key", %{"key" => "Escape"} = _attrs, socket) do
    handle_event("close", %{}, socket)
  end

  def handle_event("close-key", %{"key" => _}, socket) do
    # ignore any other key
    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    debug(
      "reset all assigns to defaults so they don't accidentally get re-used in a different modal"
    )

    {:noreply, assign(socket, [show: false] ++ default_assigns())}
  end
end
