defmodule Bonfire.UI.Common.PreviewContentLive do
  use Bonfire.UI.Common.Web, :stateful_component

  @moduledoc """
  A special 'modal' for previewing objects from a feed without redirecting to a new view (so we can go back to where we were in the feed)
  """

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: nil

  @doc """
  Force modal to be open. This works with hide_main in layout_live,
  which is the single source of truth for visibility state.
  """
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

  def handle_event("open", params, socket) do
    # When opening the preview, we hide the main content and store navigation info
    socket =
      socket
      |> assign(
        previous_url: params["previous_url"],
        previous_scroll: params["previous_scroll"]
      )
      |> send_self(hide_main: true)

    {:noreply, socket}
  end

  def handle_event("show_extra", _params, socket) do
    # Show extra content instead of preview content
    socket = socket |> send_self(hide_main: true)
    {:noreply, socket}
  end

  def handle_event("close", _params, socket) do
    # When closing, show main content again
    socket =
      socket
      |> send_self(
        hide_main: false,
        modal_assigns: Enums.fun(e(assigns(socket), :modal_assigns, %{}), :put, [:loaded, false])
      )

    {:noreply, socket}
  end
end
