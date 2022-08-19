defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :atom, default: nil
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: nil
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop showing_within, :any, default: nil
  prop with_rich_editor, :boolean, default: true, required: false
  prop activity, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: false
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop show_select_recipients, :boolean, default: false
  prop thread_mode, :atom, default: nil
  prop page, :any, default: nil

  def set_smart_input_as(:flat, _), do: :sidebar
  def set_smart_input_as(_, context), do: Settings.get([:ui, :smart_input_as], :floating, context)

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
