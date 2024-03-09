defmodule Bonfire.UI.Common.PreviewContentLive do
  use Bonfire.UI.Common.Web, :stateful_component

  @moduledoc """
  A special 'modal' for previewing objects from a feed without redirecting to a new view (so we can go back to where we were in the feed)
  """

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: nil

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  @doc "Optional prop to hide the header at the top of the modal"
  prop no_header, :boolean, default: false

  @doc "The classes of the modal."
  prop modal_class, :string, default: nil

  @doc """
  Additional assigns for the modal
  """
  prop modal_assigns, :any, default: []

  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []

  @doc """
  Slots for the contents of the modal, title, buttons...
  """
  slot default, arg: [:autocomplete]
  slot open_btn
  slot action_btns
  slot cancel_btn
  slot title
  slot extra_contents

  def mount(socket) do
    # debug("mounting")
    # need this because when used in the HEEX it doesn't set Surface defaults
    {:ok,
     assign(
       socket,
       title_text: nil,
       title_class: nil,
       modal_class: nil,
       show: false,
       no_header: false,
       opts: []
     )}
  end

  def handle_event("close", _, socket) do
    debug("close")
    {:noreply, assign(socket, show: false)}
  end
end
