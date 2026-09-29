defmodule Bonfire.UI.Common.SmartInputLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  # prop user_image, :string, required: true
  # prop create_object_type, :any, default: nil
  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop composer_dom_id, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop mentions, :list, default: []
  prop context_group, :any, default: nil
  prop event_target, :any, default: nil
  prop open_boundaries, :boolean, default: false
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop quoted_object, :any, default: nil
  prop quoted_url, :string, default: nil
  # prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil

  prop page, :any, default: nil
  prop selected_cover, :any, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop reset_smart_input, :boolean, default: false

  prop uploads, :any, default: nil
  prop uploaded_files, :any, default: nil
  prop trigger_submit, :boolean, default: nil
  # Classes to customize the smart input appearance
  prop replied_activity_class, :css_class, default: "flex-1 reply_to_in_composer overflow-x-auto"

  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []

  prop custom_emojis, :any, default: []

  @doc """
  Labels the composer's current policy, without treating mixed or overridden audiences as a single preset.

      iex> group_audience_label(["members:private"], [], %{})
      "Members only"

      iex> group_audience_label([{"local", "Ignored display name"}], [], %{})
      "Local"

      iex> group_audience_label(["public", "members:private"], [], %{})
      "Custom audience"

      iex> group_audience_label(["public"], ["excluded-circle"], %{})
      "Custom audience"
  """
  def group_audience_label(boundaries, exclusions, permissions) do
    group_audience_meta(boundaries, exclusions, permissions)
    |> e(:label, l("Custom audience"))
  end

  @doc """
  Uses the audience preset's icon, or a neutral shield for custom permissions.

      iex> group_audience_icon(["members:private"], [], %{})
      "ph:lock-duotone"

      iex> group_audience_icon(["public"], [], %{})
      "ph:globe-duotone"

      iex> group_audience_icon(["public"], ["excluded-circle"], %{})
      "ph:shield-check-duotone"
  """
  def group_audience_icon(boundaries, exclusions, permissions) do
    group_audience_meta(boundaries, exclusions, permissions)
    |> e(:icon, "ph:shield-check-duotone")
  end

  defp group_audience_meta(boundaries, [], permissions) when permissions == %{} do
    case List.wrap(boundaries) do
      [{slug, _label}] when is_binary(slug) ->
        group_audience_meta([slug], [], permissions)

      [slug] when is_binary(slug) ->
        Bonfire.Boundaries.Presets.dimension_meta(:default_content_visibility, slug)

      _ ->
        nil
    end
  end

  defp group_audience_meta(_, _, _), do: nil

  def post_content(object) do
    e(object, :post_content, nil) || object
  end

  @doc """
  Whether the composer is currently scoped to a reply target.

  Used to switch the composer into "reply mode" (showing the replied-to
  context, hiding the create-type picker, relabelling the submit button).
  """
  def replying?(assigns) do
    is_map(e(assigns, :activity, nil)) or is_map(e(assigns, :reply_to_id, nil))
  end

  @doc """
  Display name and `@handle` of the author of the activity/object being
  replied to, for the "Replying to …" banner. Falls back gracefully when the
  subject can't be resolved (e.g. an id-only `reply_to_id`).
  """
  def reply_to_author(assigns) do
    subject =
      e(assigns, :activity, :subject, nil) ||
        e(assigns, :object, :created, :creator, nil) ||
        e(assigns, :object, :creator, nil)

    %{
      name: e(subject, :profile, :name, nil) || e(subject, :character, :username, nil),
      handle:
        maybe_apply(Bonfire.Me.Characters, :display_username, [subject, true],
          fallback_return: nil
        )
    }
  end
end
