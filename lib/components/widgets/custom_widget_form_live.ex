defmodule Bonfire.UI.Common.CustomWidgetFormLive do
  @moduledoc "Where an admin writes a custom widget: its title, its text in markdown, and its width. Stored at instance scope under `[Bonfire.UI.Common.Widgets, :custom, slug]`, and offered in every place once it has text (see `Bonfire.UI.Common.Widgets`). Emptying the text takes it out of every place."
  use Bonfire.UI.Common.Web, :stateless_component

  prop slug, :atom, default: :text
  prop class, :css_class
end
