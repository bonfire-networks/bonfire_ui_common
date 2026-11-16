defmodule Bonfire.UI.Common.FeedbackCtaLive do
  @moduledoc "The feedback widget's button, also the getting-started checklist's wishes step: a link to the instance's feedback form, or the composer opened in its group or topic, as `Bonfire.UI.Common.WidgetFeedbackLive.cta_for/1` says. Renders nothing when the instance is asking nothing."
  use Bonfire.UI.Common.Web, :stateless_component

  # what `WidgetFeedbackLive.cta_for/1` returned, when the caller has already worked it out (the widget has, to decide whether to show at all); `nil` and this works it out itself
  prop cta, :any, default: nil
end
