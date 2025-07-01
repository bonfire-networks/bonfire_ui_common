defmodule Bonfire.UI.Common.SmartInputLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  # prop user_image, :string, required: true
  # prop create_object_type, :any, default: nil
  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop mentions, :list, default: []
  prop open_boundaries, :boolean, default: false
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  # prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil

  prop page, :any, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop reset_smart_input, :boolean, default: false

  prop uploads, :any, default: nil
  prop uploaded_files, :any, default: nil
  prop trigger_submit, :boolean, default: nil
  # Classes to customize the smart input appearance
  prop replied_activity_class, :css_class, default: "flex-1 overflow-x-auto"

  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :any, default: nil

  prop custom_emojis, :any, default: []

  def post_content(object) do
    e(object, :post_content, nil) || object
  end
end
