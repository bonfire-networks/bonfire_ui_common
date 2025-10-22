defmodule Bonfire.UI.Common.WriteEditorLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils

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
  prop verb_permissions, :map, default: %{}
  prop to_boundaries, :list, default: []
  prop boundary_preset, :any, default: nil
  prop preview_boundary_for_id, :string, default: nil
  prop preview_boundary_for_username, :string, default: nil
  prop preview_boundary_verbs, :list, default: []
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []

  def use_rich_editor?(with_rich_editor, opts) do
    with_rich_editor == true and
      Bonfire.Common.Settings.get([:ui, :rich_text_editor_disabled], false, opts) != true
  end

  def rich_editor_module(with_rich_editor, opts) do
    if use_rich_editor?(with_rich_editor, opts) do
      default = opts[:default] || Bonfire.UI.Common.ComposerLive

      module =
        Bonfire.Common.Settings.get([:ui, :rich_text_editor], default, opts)
        |> debug("Rich editor module")

      if module_enabled?(module, opts),
        do: module,
        else: error(nil, "#{module} is not available or enabled")
    end
  end
end
