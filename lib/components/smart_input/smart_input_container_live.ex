defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive

  prop reply_to_id, :any, default: nil
  prop as_icon, :boolean, default: false
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop open_boundaries, :boolean, default: false
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop selected_cover, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop mentions, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop activity, :any, default: nil
  # prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  # prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil

  # prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  prop composer_class, :css_class, default: nil
  # prop without_sidebar, :string, default: nil
  prop reset_smart_input, :boolean, default: false
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []

  def mount(socket),
    do:
      {:ok,
       socket
       |> maybe_setup_uploads()}

  def maybe_setup_uploads(socket) do
    max_file_size =
      (Bonfire.Common.Utils.maybe_apply(
         Bonfire.Files.VideoUploader,
         :max_file_size,
         [],
         fallback_return: nil
       ) ||
         Bonfire.Common.Utils.maybe_apply(
           Bonfire.Files.DocumentUploader,
           :max_file_size,
           [],
           fallback_return: nil
         ) ||
         Bonfire.Common.Utils.maybe_apply(
           Bonfire.Files.ImageUploader,
           :max_file_size,
           [],
           fallback_return: nil
         ) || 20_000_000)
      |> debug("max_file_size")

    maybe_setup_uploads(socket, max_file_size)
  end

  def maybe_setup_uploads(socket, max_file_size) do
    socket
    |> assign(
      trigger_submit: false,
      uploaded_files: []
    )
    |> allow_upload(:files,
      accept:
        Config.get_ext(
          :bonfire_files,
          :all_allowed_media_types,
          ~w(.jpg .png)
        ),
      # make configurable
      max_file_size: max_file_size,
      max_entries:
        Config.get(
          [Bonfire.UI.Common.SmartInputLive, :max_uploads],
          4
        ),
      auto_upload: false
      # progress: &handle_progress/3
    )
  end

  # Handle targeted updates from SelectRecipientsLive - only modify specific field
  def update(%{update_field: field, field_value: value, preserve_state: true}, socket) do
    {:ok, socket |> assign(field, value) |> assign(reset_smart_input: false)}
  end

  # Merge smart_input_opts when both old and new are maps
  def update(
        %{smart_input_opts: new_smart_input_opts} = assigns,
        %{assigns: %{smart_input_opts: old_smart_input_opts}} = socket
      )
      when is_map(new_smart_input_opts) and is_map(old_smart_input_opts) do
    merged_opts = Map.merge(old_smart_input_opts, new_smart_input_opts)

    {:ok,
     socket
     |> Bonfire.Boundaries.LiveHandler.prepare_assigns()
     |> assign(preserve_reply_state(assigns, socket))
     |> assign(:smart_input_opts, merged_opts)}
  end

  # Default update handler
  def update(assigns, socket) do
    # Custom emojis are loaded lazily when the emoji picker is opened
    {:ok,
     socket
     |> assign(preserve_reply_state(assigns, socket))
     |> Bonfire.Boundaries.LiveHandler.prepare_assigns()
     |> assign(reset_smart_input: false, custom_emojis: "[]")}
  end

  # Preserve reply state fields if they exist and incoming values are nil
  # This ensures minimize/maximize doesn't clear the reply_to state
  defp preserve_reply_state(assigns, socket) do
    assigns
    |> maybe_preserve_assign(:activity, e(assigns(socket), :activity, nil))
    |> maybe_preserve_assign(:object, e(assigns(socket), :object, nil))
    |> maybe_preserve_assign(:reply_to_id, e(assigns(socket), :reply_to_id, nil))
    |> maybe_preserve_assign(:to_boundaries, e(assigns(socket), :to_boundaries, nil))
  end

  defp maybe_preserve_assign(assigns, key, nil), do: assigns

  defp maybe_preserve_assign(assigns, key, existing_value) do
    if Map.get(assigns, key) == nil do
      Map.put(assigns, key, existing_value)
    else
      assigns
    end
  end

  def handle_event(_action, _attrs, socket) do
    socket |> Bonfire.Boundaries.LiveHandler.prepare_assigns()
  end

  # Removed the handle_info handler to avoid conflicts with PersistentLive
end
