defmodule Bonfire.UI.Common.ReusableModalLive do
  use Bonfire.UI.Common.Web, :stateful_component
  @moduledoc """
  The classic **modal**
  """

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: "font-bold text-base"

  @doc "The classes of the open button for the modal. Only used if no open_btn slot is passed."
  prop open_btn_class, :css_class, default: "btn btn-primary btn-sm normal-case"

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :css_class, default: "btn btn-outline btn-sm normal-case"

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

  def handle_event("close", _, socket) do
    {:noreply, assign(socket, show: false)}
  end

end
