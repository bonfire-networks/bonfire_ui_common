defmodule Bonfire.UI.Common.OpenModalLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.ReusableModalLive

  @default_modal_id "modal"

  @doc "The title of the button used to open the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_text, :string, default: nil

  @doc "If the modal is a preview of an image, set this to true."
  prop image_preview, :boolean, default: false

  @doc "The title of the modal. Only used if no `title` slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: "font-bold text-base flex-1 modal-title"

  prop main_wrapper_class, :css_class, default: "w-full"
  prop open_btn_wrapper_class, :css_class, default: ""
  @doc "The classes of the open button for the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_class, :css_class, default: ""

  prop open_btn_opts, :any, default: []

  @doc "Optional link on the open btn."
  prop href, :string, default: nil

  @doc "Optional JS hook on the open btn."
  prop open_btn_hook, :string, default: nil

  prop click_open_event, :string, default: "open"

  @doc "The classes of the modal wrapper."
  prop wrapper_class, :css_class, default: nil

  prop without_form, :boolean, default: false

  @doc "The classes of the modal"
  prop modal_class, :css_class, default: ""

  @doc "The classes around the action/submit button(s) on the modal"
  prop action_btns_wrapper_class, :css_class, default: nil

  @doc "The classes of the close/cancel button on the modal. Only used if no `close_btn` slot is passed."
  prop cancel_btn_class, :css_class, default: "btn btn-outline btn-sm"

  prop cancel_label, :string, default: nil

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :map, default: %{}

  @doc "Optional prop to hide the header at the top of the modal"
  prop no_header, :boolean, default: false

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  prop no_backdrop, :boolean, default: false

  prop enable_fallback, :boolean, default: false

  @doc "The classes of the title of the modal"
  prop reusable_modal_component, :atom, default: ReusableModalLive

  @doc "The ID of this instance of the modal"
  prop reusable_modal_id, :string, default: nil

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

  # prop value, :any, default: nil
  data value, :any, default: nil

  @doc """
  Slot for the contents of the modal, title, buttons...
  """
  slot title
  slot action_btns
  slot cancel_btn
  slot default, arg: [autocomplete: :list, value: :any]

  @doc """
  Slot for the button that opens the modal
  """
  slot open_btn, arg: [autocomplete: :list, value: :any]

  def open(reusable_modal_id \\ nil) do
    debug("open!")
    set([show: true], reusable_modal_id || @default_modal_id)
  end

  def close(reusable_modal_id \\ nil) do
    debug("close!")

    set(
      [show: false] ++ ReusableModalLive.default_assigns(),
      reusable_modal_id || @default_modal_id
    )
  end

  def set(assigns, reusable_modal_id \\ nil) do
    maybe_set_assigns(
      e(
        assigns,
        :reusable_modal_component,
        ReusableModalLive
      ),
      reusable_modal_id || e(assigns, :reusable_modal_id, nil) ||
        if(e(assigns, :__context__, :sticky, nil),
          do: "persistent_modal",
          else: @default_modal_id
        ),
      assigns
    )

    # case assigns[:root_assigns] do
    #   root_assigns when is_list(root_assigns) and root_assigns !=[] ->
    #     send_self(assigns[:root_assigns])

    #   _ -> nil
    # end
  end

  def maybe_set_assigns(_component, "media_player_modal", assigns) do
    # TODO: detect if we're already in the sticky view
    Bonfire.UI.Common.PersistentLive.maybe_send(assigns, {:media_player, assigns})
  end

  def maybe_set_assigns(component, reusable_modal_id, assigns) do
    maybe_send_update(
      component,
      reusable_modal_id,
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
    set(assigns(socket))

    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    close(
      e(assigns(socket), :reusable_modal_id, nil) ||
        if(e(assigns(socket), :__context__, :sticky, nil),
          do: "persistent_modal",
          else: @default_modal_id
        )
    )

    {:noreply, socket}
  end

  def handle_event("set_value", %{"value" => value}, socket) do
    close(
      e(assigns(socket), :reusable_modal_id, nil) ||
        if(e(assigns(socket), :__context__, :sticky, nil),
          do: "persistent_modal",
          else: @default_modal_id
        )
    )

    {:noreply, socket |> assign(:value, value)}
  end
end
