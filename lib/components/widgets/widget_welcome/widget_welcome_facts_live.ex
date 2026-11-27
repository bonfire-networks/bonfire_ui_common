defmodule Bonfire.UI.Common.WidgetWelcomeFactsLive do
  @moduledoc "The Welcome widget's setting: whether the instance's facts (At a glance) show under its text."
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: nil

  @doc "What the toggle is set to, for edit mode's tile: the viewer's, or with `:instance` the instance's default."
  def current_label(context, scope) do
    context =
      if scope == :instance,
        do: Bonfire.Common.Settings.LiveHandler.scoped(scope, context),
        else: context

    if Bonfire.UI.Common.WidgetWelcomeLive.show_facts?(context),
      do: l("With At a glance"),
      else: l("Text only")
  end
end
