defmodule Bonfire.UI.Common.WriteEditorLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  # alias Surface.Components.Form
  # alias Surface.Components.Form.HiddenInput
  # alias Surface.Components.Form.TextInput
  # alias Surface.Components.Form.Field
  # alias Surface.Components.Form.Inputs
  prop reset_smart_input, :boolean, default: false
  prop field_name, :string, default: "post[post_content][html_body]", required: false
  prop create_object_type, :any, default: nil
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop insert_text, :string, default: nil
  prop thread_mode, :atom, default: nil
  # Classes to customize the smart input appearance
  prop textarea_class, :css_class, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop advanced_mode, :boolean, default: false

  def use_rich_editor?(with_rich_editor, context) do
    with_rich_editor == true and
      Bonfire.Me.Settings.get([:ui, :rich_text_editor_disabled], false, context) != true
  end

  def rich_editor_module(with_rich_editor, context) do
    if use_rich_editor?(with_rich_editor, context) do
      default = Bonfire.UI.Common.ComposerLive
      module = Bonfire.Me.Settings.get([:ui, :rich_text_editor], default, context)

      if module_enabled?(module, context),
        do: module,
        else: error(nil, "#{module} is not available or enabled")
    end
  end
end
