defmodule Bonfire.UI.Common.PolicyDropdownLive do
  @moduledoc """
  A composer policy menu, such as reply or group visibility: the current choice as the trigger, and the allowed choices as a checked list. Each choice sends `event` with its id; which choices are allowed is decided by the caller (and re-validated by the event handler).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, required: true

  @doc "Accessible name of the control, e.g. \"Visible to\"."
  prop label, :string, required: true

  prop icon, :string, required: true
  prop selected_label, :string, required: true

  @doc "Extra attributes for the selected-choice status, e.g. a `data-role`."
  prop status_opts, :list, default: []

  prop description, :string, default: nil

  @doc "Maps with `:id`, `:label`, `:selected?` and an optional `:icon`."
  prop options, :list, default: []

  prop event, :string, required: true

  @doc "Data attribute naming each choice, e.g. `data-reply-audience`."
  prop option_attr, :string, required: true

  prop event_target, :any, default: nil
end
