defmodule Bonfire.UI.Common.VocabularySettingsLive do
  @moduledoc """
  For each kind of block whose wording can be chosen (see `Bonfire.Common.Vocabulary`), a select of the presets and "Custom…". Choosing "Custom…" shows a field for each phrase of the block, to word it in one's own words. Rendered inside the preferences page for the scope being edited, so the same form serves the user and the instance's admin.
  """
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Vocabulary

  prop scope, :any, default: nil

  @doc "The settings the scope being edited reads from (see `Bonfire.Common.Settings.LiveHandler.scoped/2`), to tell whether it has chosen \"Custom…\"."
  prop scoped, :any, default: nil

  @doc "Whether the scope chose to word a kind in its own words, which is when its fields are shown."
  def custom?(kind, scoped), do: Vocabulary.preset_id(kind, context: scoped) == :custom

  @doc "What the field of a phrase is called. A phrase this does not know is named by its key."
  def phrase_label(:title), do: l("Title")
  def phrase_label(:empty), do: l("Message when there is nothing to show")
  def phrase_label(:view_all), do: l("Label of the \"View all\" link")
  def phrase_label(key), do: key |> to_string() |> String.replace("_", " ") |> String.capitalize()

  @doc "The wording a blank field falls back to, shown in it so it is clear what typing replaces."
  def default_text(kind, key), do: Vocabulary.phrase(Vocabulary.default_preset(kind), key) || ""
end
