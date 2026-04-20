defmodule Bonfire.UI.Common.InlineComposerPlaceholderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop category, :any, required: true
  prop prompt, :any, default: nil
  prop selected_tab, :any, default: nil

  @hidden_tabs ~w(settings members followers mentions submitted)

  def show?(selected_tab),
    do: to_string(selected_tab || "") not in @hidden_tabs

  def scope_label(category) do
    name = Bonfire.Classify.Web.Preview.CategoryLive.name(category, l("group"))

    if e(category, :type, nil) == :topic, do: "#" <> name, else: name
  end
end
