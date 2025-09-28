defmodule Bonfire.UI.Common.InputControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop preloaded_recipients, :list, default: nil
  prop smart_input_opts, :map, default: %{}
  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil
  # prop create_object_type, :any, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop mentions, :list, default: []
  prop showing_within, :atom, default: nil

  prop uploads, :any, default: nil
  prop uploaded_files, :list, default: []

  prop selected_cover, :any, default: nil
  prop event_target, :string, default: nil
  prop page, :any, default: nil
  prop show_cw_toggle, :boolean, default: false
  prop submit_label, :string, default: nil
  prop open_boundaries, :boolean, default: false

  prop reset_smart_input, :boolean, default: false
  prop boundaries_modal_id, :string, default: :sidebar_composer

  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []
  prop boundary_preset, :any, default: nil

  prop custom_emojis, :any, default: []
  slot default

  def render(assigns) do
    # Load custom emojis
    assigns
    |> assign(
      :enable_thread_title,
      !assigns[:reply_to_id] and Config.get([:ui, :smart_input, :title]) == true
    )
    |> assign(
      :boundary_preset,
      Bonfire.Common.Utils.maybe_apply(
        Bonfire.UI.Boundaries.SetBoundariesLive,
        :boundaries_to_preset,
        [assigns[:to_boundaries]]
      )
    )
    |> render_sface()
  end
end
