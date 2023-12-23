defmodule Bonfire.UI.Common.InlineModalLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Common.ReusableModalLive

  prop id, :any, default: nil

  @doc "The title of the button used to open the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_text, :string, default: nil

  @doc "If the modal is a preview of an image, set this to true."
  prop image_preview, :boolean, default: false

  @doc "The title of the modal. Only used if no `title` slot is passed."
  prop title_text, :string, default: nil

  @doc "The classes of the title of the modal"
  prop title_class, :css_class, default: "font-bold text-base flex-1 modal-title"

  @doc "The classes of the open button for the modal. Only used if no `open_btn` slot is passed."
  prop open_btn_class, :css_class, default: ""

  prop open_btn_wrapper_class, :css_class, default: ""

  prop open_btn_opts, :any, default: []

  @doc "Optional link on the open btn."
  prop href, :string, default: nil

  @doc "Optional JS hook on the open btn."
  prop open_btn_hook, :string, default: nil

  @doc "The classes of the modal wrapper."
  prop wrapper_class, :css_class, default: nil

  prop without_form, :boolean, default: false

  @doc "The classes of the modal"
  prop modal_class, :css_class, default: "max-h-[100%]"

  @doc "The classes around the action/submit button(s) on the modal"
  prop action_btns_wrapper_class, :css_class, default: nil

  @doc "The classes of the close/cancel button on the modal. Only used if no `close_btn` slot is passed."
  prop cancel_btn_class, :css_class, default: "btn btn-ghost rounded btn-sm normal-case"

  prop cancel_label, :string, default: nil

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  prop form_opts, :map, default: %{}

  @doc "Optional prop to hide the header at the top of the modal"
  prop no_header, :boolean, default: false

  @doc "Optional prop to hide the actions at the bottom of the modal"
  prop no_actions, :boolean, default: false

  prop event_target, :any, default: nil

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
end
