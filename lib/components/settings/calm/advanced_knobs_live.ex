defmodule Bonfire.UI.Common.Settings.Calm.AdvancedKnobsLive do
  @moduledoc """
  Level 3 of the calm-empowerment settings pattern (see `Bonfire.Common.Settings.Calm`): the full per-knob editor behind a native `<details>` disclosure, prefilled with the current EFFECTIVE values (so preset/toggle composition is never invisible).

  Editing any knob declaratively flips the consumer's preset to `:custom` via the hidden `preset_field` input — no bespoke handle_event; everything posts to the generic `Bonfire.Common.Settings:set` funnel.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Event the form posts on change; override to funnel edits to a component instead of Settings."
  prop event_name, :string, default: "Bonfire.Common.Settings:set"
  @doc "Optional `phx-target` (e.g. a component DOM selector) for `event_name`."
  prop event_target, :any, default: nil
  @doc "Settings scope; pass `nil` to omit (when not posting to the Settings funnel)."
  prop scope, :atom, default: :instance
  @doc "The disclosure's summary label."
  prop summary, :string, required: true
  prop icon, :string, default: "ph:sliders-horizontal-duotone"
  @doc "data-role for the details element (test selector hook)."
  prop details_role, :string, default: "calm_advanced"
  @doc "Used for the form's `data-scope` attribute."
  prop form_name, :string, required: true

  @doc "The consumer's preset field name — submitted as `custom` alongside any edit. Pass `nil` when knob edits shouldn't flip a preset."
  prop preset_field, :string, default: nil

  @doc "Optional extra content shown inside the disclosure, below the knobs form."
  slot default
  @doc "Knob rows: maps with `:name` and `:value` (optional `:min`, default 1)."
  prop rows, :list, required: true
  @doc "Form field prefix; each knob submits as `<field_prefix>[<name>]`."
  prop field_prefix, :string, required: true
  @doc "data-role for each knob row (test selector hook)."
  prop row_role, :string, default: "calm_knob_row"
end
