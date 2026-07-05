defmodule Bonfire.UI.Common.Settings.Calm.PresetCardsLive do
  @moduledoc """
  Level 1 of the calm-empowerment settings pattern (see `Bonfire.Common.Settings.Calm`): rich preset radio-cards.

  Native radios + `peer-checked`/`has-[:checked]` CSS own the selected state (clicking highlights instantly, before the server round-trip); the form posts to the generic `Bonfire.Common.Settings:set` funnel; the optional hidden `clear_field` input resets the consumer's Level-3 overrides so picking a card returns to a pure preset; `phx-update="ignore"` keeps the post-save re-render from resetting the choice.
  """
  use Bonfire.UI.Common.Web, :stateless_component

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
  @doc "Preset cards: maps with `:value`, `:name`, `:icon`, `:description`."
  prop cards, :list, required: true
  @doc "Unique DOM id for the `phx-update=\"ignore\"` options wrapper."
  prop options_id, :string, required: true
  @doc "data-role for each card's name (test selector hook)."
  prop preset_role, :string, default: "calm_preset"
end
