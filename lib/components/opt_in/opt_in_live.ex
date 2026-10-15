defmodule Bonfire.UI.Common.OptInLive do
  @moduledoc """
  A checkbox for a choice that goes further than the action it sits in, inside that action's confirmation form.

  It shows three things, each written by the caller for its own purpose: `offer`, why someone would want it, as the label; `what`, what it actually does; and `risk`, what it costs, set apart as a warning so that it doesn't read as more explanation.

  Unticked, it sends `"false"` rather than nothing, so a handler reading the field with `Types.maybe_to_boolean/1` gets `false` for "no", and `nil` only where the form didn't offer it.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The form field name"
  prop name, :string, required: true

  @doc "Why someone would want this, as the checkbox label"
  prop offer, :string, required: true

  @doc "What it actually does"
  prop what, :string, default: nil

  @doc "What it costs"
  prop risk, :string, default: nil

  prop checked, :boolean, default: false

  @doc "For tests and scripts to find it by, defaults to the `name`"
  prop data_role, :string, default: nil
end
