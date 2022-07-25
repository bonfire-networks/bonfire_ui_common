defmodule Bonfire.UI.Common.ReusableModalLive do
  use Bonfire.UI.Common.Web, :stateful_component
  @moduledoc """
  The classic **modal**
  """

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default:

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :css_class, default: nil

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :any, default: []

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []


  @doc """
  Slots for the contents of the modal, title, buttons...
  """
  slot default
  slot open_btn
  slot action_btns
  slot cancel_btn
  slot title

  def mount(socket) do
    # debug("mounting")
    # need this because ReusableModalLive used in the HEEX doesn't set Surface defaults
    {:ok, socket
      |> assign(
        title_text: nil,
        title_class: nil,
        cancel_btn_class: nil,
        show: false,
        form_opts: [],
        no_actions: false,
        opts: []
      )
    }
  end

  def handle_event("close", _, socket) do
    debug("close")
    {:noreply, assign(socket, show: false)}
  end

end
