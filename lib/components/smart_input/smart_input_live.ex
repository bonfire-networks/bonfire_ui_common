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
  Labels the composer's reading audience. Reply and quote overrides do not change the readers; mixed, excluded or otherwise overridden audiences remain custom.

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
  Uses the reading audience's preset icon, or a neutral shield when the audience is custom.

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

  @doc """
  Whether exclusions or reading overrides make the audience custom rather than a single preset. Reply and quote overrides don't change who can read.

      iex> custom_audience?([], %{"reply" => %{"circle-id" => :cannot}})
      false

      iex> custom_audience?([], %{"read" => %{"circle-id" => :cannot}})
      true
  """
  def custom_audience?(exclusions, permissions) when is_map(permissions),
    do: exclusions != [] or map_size(reading_overrides(permissions)) > 0

  # an unknown permissions shape stays custom, as in `group_audience_label/3`
  def custom_audience?(_, _), do: true

  defp reading_overrides(permissions), do: Map.drop(permissions, [:reply, :quote, "reply", "quote"])

  defp group_audience_meta(boundaries, [], permissions) when is_map(permissions) do
    case {List.wrap(boundaries), reading_overrides(permissions)} do
      {[{slug, _label}], overrides} when is_binary(slug) and map_size(overrides) == 0 ->
        group_audience_meta([slug], [], overrides)

      {["moderators"], overrides} when map_size(overrides) == 0 ->
        %{label: l("Group moderators only"), icon: "ph:shield-check-duotone"}

      {[slug], overrides} when is_binary(slug) and map_size(overrides) == 0 ->
        Bonfire.Boundaries.Presets.dimension_meta(:default_content_visibility, slug)

      _ ->
        nil
    end
  end

  defp group_audience_meta(_, _, _), do: nil

  @doc """
  Labels the supported reply ceilings; unknown choices keep the inherited label.

      iex> reply_audience_label("clone_context")
      "Same as original post"

      iex> reply_audience_label("reply_participants")
      "Original author and you"
  """
  def reply_audience_label([{audience, _} | _]), do: reply_audience_label(to_string(audience))
  def reply_audience_label([audience | _]), do: reply_audience_label(to_string(audience))
  def reply_audience_label("reply_members"), do: l("Group members")
  def reply_audience_label("reply_moderators"), do: l("Group moderators")
  def reply_audience_label("reply_participants"), do: l("Original author and you")
  def reply_audience_label(_), do: l("Same as original post")

  @doc "Whether the composer is scoped to a named group or topic, which then decides the post's visibility choices."
  def group_context?(context_group) do
    case e(context_group, :name, nil) do
      name when is_binary(name) and name != "" -> true
      _ -> false
    end
  end

  @doc "Reply visibility choices, from the audiences validated when the reply was opened."
  def reply_audience_options(smart_input_opts, to_boundaries) do
    for audience <- e(smart_input_opts, :reply_audiences, ["clone_context"]) do
      %{
        id: audience,
        label: reply_audience_label(audience),
        selected?: Bonfire.UI.Boundaries.GeneralAccessListLive.matches?(to_boundaries, audience)
      }
    end
  end

  @doc "Visibility choices within the composer's group or topic."
  def group_audience_options(context_group, to_boundaries) do
    for audience <- e(context_group, :audiences, []) do
      %{
        id: audience,
        label: group_audience_label([audience], [], %{}),
        icon: group_audience_icon([audience], [], %{}),
        selected?: Bonfire.UI.Boundaries.GeneralAccessListLive.matches?(to_boundaries, audience)
      }
    end
  end

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
