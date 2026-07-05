defmodule Bonfire.UI.Common.Settings.Calm.PresetCardsLive do
  @moduledoc """
  Level 1 of the calm-empowerment settings pattern (see `Bonfire.Common.Settings.Calm`): rich preset radio-cards.

  Native radios + `peer-checked`/`has-[:checked]` CSS own the selected state (clicking highlights instantly, before the server round-trip); the form posts to the generic `Bonfire.Common.Settings:set` funnel; the optional hidden `clear_field` input resets the consumer's Level-3 overrides so picking a card returns to a pure preset; `phx-update="ignore"` keeps the post-save re-render from resetting the choice.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Event the form posts on change; override to funnel picks to a component instead of Settings."
  prop event_name, :string, default: "Bonfire.Common.Settings:set"
  @doc "Optional `phx-target` (e.g. a component DOM selector) for `event_name`."
  prop event_target, :any, default: nil
  @doc "Settings scope; pass `nil` to omit (when not posting to the Settings funnel)."
  prop scope, :atom, default: :instance
  @doc "Used for the form's `name`/`data-scope` attributes."
  prop form_name, :string, required: true
  prop title, :string, default: nil
  prop description, :string, default: nil
  @doc "Accessible fieldset legend."
  prop legend, :string, default: nil
  @doc "The radio input name, mapping to the consumer's preset settings key."
  prop field_name, :string, required: true
  @doc "Optional hidden input name submitted empty to clear Level-3 overrides on preset pick."
  prop clear_field, :string, default: nil
  @doc "Currently-selected preset, as a string."
  prop current, :string, required: true
  @doc "Preset cards: maps with `:value`, `:name`, `:icon` and optionally `:description`."
  prop cards, :list, required: true
  @doc "Unique DOM id for the `phx-update=\"ignore\"` options wrapper."
  prop options_id, :string, required: true
  @doc "data-role for each card's name (test selector hook)."
  prop preset_role, :string, default: "calm_preset"

  @doc "Class of the wrapping form."
  prop class, :css_class, default: "p-4 border-b border-base-content/10"
  @doc "Class of the options wrapper (e.g. swap the stacked list for a grid: `grid sm:grid-cols-2 gap-2`)."
  prop options_class, :css_class, default: "grid sm:grid-cols-2 gap-2"
  @doc "Class of each card (a `<label>` wrapping a sr-only radio — keep the `has-[:checked]`/`has-[:focus-visible]` variants so selection & focus stay visible)."
  prop card_class, :css_class,
    default:
      "relative flex flex-wrap items-start gap-x-3 gap-y-2 rounded-lg border border-base-content/10 p-3 cursor-pointer transition-colors hover:border-base-content/30 hover:bg-base-content/5 has-[:checked]:border-primary has-[:checked]:bg-primary/10 has-[:checked]:ring-1 has-[:checked]:ring-primary has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-primary has-[:focus-visible]:ring-offset-1 has-[:focus-visible]:ring-offset-base-100"

  @doc "Class of the icon circle (keep the `peer-checked:` variants for the selected state); pass `\"hidden\"` to drop icons entirely."
  prop icon_wrapper_class, :css_class,
    default:
      "flex-shrink-0 flex items-center justify-center w-9 h-9 rounded-full transition-colors bg-base-content/10 text-muted peer-checked:bg-primary peer-checked:text-primary-content"

  @doc "Class of the card name."
  prop name_class, :css_class, default: "text-sm font-medium text-base-content"
  @doc "Class of the card description."
  prop description_class, :css_class, default: "text-xs text-muted leading-snug"
end
