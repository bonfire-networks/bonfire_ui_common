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
    smart_input_opts = assigns[:smart_input_opts] || %{}
    create_object_type = e(smart_input_opts, :create_object_type, nil)
    # NOTE: `reply_to_id` is checked with `in [nil, ""]` (not `!reply_to_id`) because the
    # composer passes an empty string for non-replies, and `!""` is `false` in Elixir.
    not_a_reply? = assigns[:reply_to_id] in [nil, ""]

    # read once (keyword list, so per-extension config deep-merges)
    enable_fields = Config.get([Bonfire.UI.Common.InputControlsLive, :enable_fields], [])
    title = field_config(enable_fields, :title, create_object_type)
    summary = field_config(enable_fields, :summary, create_object_type)
    sensitive = field_config(enable_fields, :sensitive, create_object_type)

    summary_visible = summary[:show_by_default] == true
    sensitive_toggle = sensitive[:enable_toggle] == true
    show_cw = e(smart_input_opts, :show_cw, false)
    show_sensitive = e(smart_input_opts, :show_sensitive, false)

    assigns
    |> assign(:title_visible, not_a_reply? and title[:show_by_default] == true)
    |> assign(:title_toggle, not_a_reply? and title[:enable_toggle] == true)
    |> assign(:summary_visible, summary_visible)
    |> assign(:sensitive_toggle, sensitive_toggle)
    |> assign(:show_cw, show_cw)
    |> assign(:show_sensitive, show_sensitive)
    # The summary/CW field shows when it's a default summary (article), OR when CW is active
    # AND this type actually supports CW — otherwise lingering CW state (e.g. after switching
    # from a post to a poll) would keep the field with no siren to turn it off.
    |> assign(
      :summary_field_shown,
      summary_visible or ((show_sensitive or show_cw) and sensitive_toggle)
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

  # Per-field, per-type composer field config. Driven by config (keyword lists, so each
  # extension's config deep-merges) so this generic component has no type-specific
  # knowledge — each extension enables its own type, e.g.:
  #
  #     config :bonfire_ui_common, Bonfire.UI.Common.InputControlsLive,
  #       enable_fields: [
  #         title: [article: [show_by_default: true], post: [enable_toggle: true]],
  #         summary: [article: [show_by_default: true]],
  #         sensitive: [default: [enable_toggle: true]]
  #       ]
  #
  # `:show_by_default` shows the field expanded; `:enable_toggle` shows a button to
  # reveal/hide it. Falls back to a `:default` type entry when the type isn't configured.
  defp field_config(enable_fields, field, create_object_type) do
    config = ed(enable_fields, field, []) || []
    # config keys are atoms, but create_object_type can arrive as a string (e.g. "post"
    # from the form) or atom (e.g. :article) — normalise so the lookup matches.
    type = Bonfire.Common.Types.maybe_to_atom(create_object_type) || create_object_type
    ed(config, type, nil) || ed(config, :default, nil) || []
  end
end
