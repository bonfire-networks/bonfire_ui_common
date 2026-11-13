defmodule Bonfire.UI.Common.FeedbackCtaLive do
  @moduledoc "The feedback widget's button, also the getting-started checklist's wishes step: a link to the instance's feedback form, or the composer opened in its group or topic, as `Bonfire.UI.Common.WidgetFeedbackLive.cta_for/1` says. Renders nothing when the instance is asking nothing."
  use Bonfire.UI.Common.Web, :stateless_component
end
