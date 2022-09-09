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
  prop without_sidebar, :string, default: nil

  def set_smart_input_as(:flat, _), do: :sidebar
  def set_smart_input_as(_, context), do: Settings.get([:ui, :smart_input_as], :floating, context)


end
