defmodule Bonfire.UI.Common.SmartInputHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop smart_input_prompt, :string, required: false
  prop smart_input_component, :atom, default: nil
  prop create_activity_type, :atom, default: nil

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
