defmodule Bonfire.UI.Common.Settings.Calm.OverrideTogglesLive do
  @moduledoc """
  Level 2 of the calm-empowerment settings pattern (see `Bonfire.Common.Settings.Calm`): outcome-named override toggles that each bump a curated bundle of knobs ON TOP of the selected preset, without changing it.

  DaisyUI toggles can either submit the containing form or post their key and desired state individually, so consumers can choose the event contract they need.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Event sent by the form or each toggle; override to funnel changes to a component instead of Settings."
  prop event_name, :string, default: "Bonfire.Common.Settings:set"
  @doc "Optional `phx-target` (e.g. a component DOM selector) for `event_name`."
  prop event_target, :any, default: nil

  @doc "`:form` serializes the complete form; `:click` sends each toggle's `key` and desired `on` state independently."
  prop event_mode, :atom, default: :form, values: [:form, :click]
  @doc "Settings scope; pass `nil` to omit (when not posting to the Settings funnel)."
  prop scope, :atom, default: :instance
  @doc "Used for the form's `data-scope` attribute."
  prop form_name, :string, required: true

  @doc "Unique DOM id for the form; defaults to `\"<form_name>_form\"` (pass explicitly when several instances of the same form can coexist, e.g. per feed)."
  prop form_id, :string, default: nil
  @doc "Optional data-role for the form (test selector hook)."
  prop form_role, :string, default: nil
  @doc "Form layout classes; override when a compact host surface needs a denser rhythm."
  prop form_class, :css_class, default: "p-4 border-b-hair border-secondary flex flex-col gap-3"
  @doc "Optional classes added to every toggle row, for host-specific inset and interaction styling."
  prop row_class, :css_class, default: nil
  prop title, :string, default: nil
  @doc "Title typography classes; override to quiet the heading in secondary surfaces."
  prop title_class, :css_class, default: "text-sm font-medium text-base-content"
  prop description, :string, default: nil
  @doc "Toggle rows: maps with `:key`, `:name`, `:on` and optionally `:description`."
  prop rows, :list, required: true
  @doc "Form field prefix; each toggle submits as `<field_prefix>[<key>]`."
  prop field_prefix, :string, required: true
  @doc "data-role for each row / each toggle input (test selector hooks)."
  prop row_role, :string, default: "calm_override_group"
  prop toggle_role, :string, default: "calm_override_toggle"
end
