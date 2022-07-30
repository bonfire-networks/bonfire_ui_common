defmodule Bonfire.UI.Common.OpenModalLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.ReusableModalLive

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: "font-bold text-base"

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :css_class, default: "btn btn-outline btn-sm normal-case"

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :any, default: []

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  @doc "The classes of the title of the modal"
  prop reusable_modal_id, :string, default: "modal"

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
    set(show: true)
  end

  def close() do
    debug("close!")
    set(show: false)
  end

  def set(assigns) when is_list(assigns) do
    send_update(ReusableModalLive, Keyword.put(assigns, :id, e(assigns, :reusable_modal_id, "modal")))
  end
  def set(assigns) when is_map(assigns) do
    send_update(ReusableModalLive, Map.put(assigns, :id, e(assigns, :reusable_modal_id, "modal")))
  end

  # Default event handlers

  def handle_event("open", _, socket) do
    socket = socket
    |> assign(show: true)

    set(socket.assigns) # copy all of this component's assigns to the reusable modal (including slots!)

    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    close()
    {:noreply, socket}
  end


  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
