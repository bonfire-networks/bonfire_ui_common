defmodule Bonfire.UI.Common.Settings.Calm.OverrideTogglesLive do
  @moduledoc """
  Level 2 of the calm-empowerment settings pattern (see `Bonfire.Common.Settings.Calm`): outcome-named override toggles that each bump a curated bundle of knobs ON TOP of the selected preset, without changing it.

  DaisyUI toggles with the hidden-false-then-checkbox pattern (so unchecking submits), posting to the generic `Bonfire.Common.Settings:set` funnel.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Event the form posts on change; override to funnel toggles to a component instead of Settings."
  prop event_name, :string, default: "Bonfire.Common.Settings:set"
  @doc "Optional `phx-target` (e.g. a component DOM selector) for `event_name`."
  prop event_target, :any, default: nil
  @doc "Settings scope; pass `nil` to omit (when not posting to the Settings funnel)."
  prop scope, :atom, default: :instance
  @doc "Used for the form's `data-scope` attribute."
  prop form_name, :string, required: true
  @doc "Optional data-role for the form (test selector hook)."
  prop form_role, :string, default: nil
  prop title, :string, default: nil
  prop description, :string, default: nil
  @doc "Toggle rows: maps with `:key`, `:name`, `:on` and optionally `:description`."
  prop rows, :list, required: true
  @doc "Form field prefix; each toggle submits as `<field_prefix>[<key>]`."
  prop field_prefix, :string, required: true
  @doc "data-role for each row / each toggle input (test selector hooks)."
  prop row_role, :string, default: "calm_override_group"
  prop toggle_role, :string, default: "calm_override_toggle"
end
