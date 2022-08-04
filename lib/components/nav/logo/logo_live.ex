defmodule Bonfire.UI.Common.LogoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  def all_smart_input_components do
    Bonfire.Common.Config.get([:ui, :smart_input_components], [post: Bonfire.UI.Social.WritePostContentLive])
  end

  def active_smart_input_component(smart_input_component, create_activity_type) do
    smart_input_component || e(all_smart_input_components(), create_activity_type, nil) || Bonfire.Common.Config.get([:ui, :default_smart_input]) || Bonfire.UI.Social.WritePostContentLive
  end

  def smart_input_name(component) do
    all_smart_input_components()
    |> Keyword.filter(fn {_key, val} -> val==component end)
    |> Keyword.keys()
    |> List.first()
    |> display_name()
  end

  defp display_name(name) do
    name
    |> maybe_to_string()
  end

  def set_smart_input_text(socket, text \\ "\n") do
    socket
    |> push_event("smart_input:set_body", %{text: text})
  end
  
end
