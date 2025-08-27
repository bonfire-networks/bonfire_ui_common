defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop reply_to_id, :any, default: nil
  prop as_icon, :boolean, default: false
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop open_boundaries, :boolean, default: false
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
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
  prop preview_boundary_verbs, :any, default: nil

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

  # Handle targeted updates from SelectRecipientsLive
  # This new update handler will only modify the specific field being updated
  # while preserving all other state
  def update(%{update_field: field, field_value: value, preserve_state: true}, socket) do
    # Only update the specific field without touching any other state
    socket =
      socket
      |> assign(field, value)
      |> assign(reset_smart_input: false)

    {:ok, socket}
  end

  def update(
        %{smart_input_opts: new_smart_input_opts} = assigns,
        %{assigns: %{smart_input_opts: old_smart_input_opts}} = socket
      )
      when is_map(new_smart_input_opts) and is_map(old_smart_input_opts) do
    # Merge smart_input_opts
    merged_smart_input_opts =
      Map.merge(old_smart_input_opts, new_smart_input_opts)
      |> debug("merged_smart_input_opts")

    # Preserve existing important attributes in the socket assigns
    # We'll look for essential attrs that we don't want to lose during partial updates
    existing_assigns = socket.assigns

    # Get a list of keys from the new assigns that we're updating
    new_assign_keys = Map.keys(assigns)

    # Core attributes to always preserve (unless explicitly being updated)
    core_attrs = [
      :activity,
      :object,
      :reply_to_id,
      :context_id,
      :activity_inception,
      :to_boundaries,
      :to_circles
    ]

    # Preserve core attributes if they're not being explicitly updated
    preserved_attrs =
      Enum.reduce(core_attrs, %{}, fn attr, acc ->
        if attr not in new_assign_keys and Map.has_key?(existing_assigns, attr) do
          # This is a core attribute that exists in current state but isn't being updated
          # So we should preserve it
          Map.put(acc, attr, Map.get(existing_assigns, attr))
        else
          # Either this attribute is being updated or doesn't exist in current state
          acc
        end
      end)

    # Create final assigns by merging: preserved attributes + incoming assigns + merged smart_input_opts
    final_assigns =
      preserved_attrs
      |> Map.merge(assigns)
      |> Map.put(:smart_input_opts, merged_smart_input_opts)

    {:ok,
     socket
     |> assign(final_assigns)
     |> Bonfire.Boundaries.LiveHandler.prepare_assigns()}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    # Load custom emojis
    custom_emojis =
      case Bonfire.Files.EmojiUploader.list(assigns(socket)) do
        # Return empty JSON array if no emojis
        nil ->
          "[]"

        emojis ->
          emojis
          |> Enum.map(fn {shortcode, emoji} ->
            url = e(emoji, :url, nil) || Media.emoji_url(emoji)

            if shortcode && url && !e(emoji, :archived, nil) do
              %{
                id: id(emoji),
                name: e(emoji, :label, nil),
                shortcodes: [shortcode],
                url: url
              }
            end
          end)
          |> debug("emoooji")
          |> Enums.filter_empty([])
          |> Jason.encode!()
      end

    {
      :ok,
      socket
      |> Bonfire.Boundaries.LiveHandler.prepare_assigns()
      # TODO: only trigger if module enabled ^
      |> assign(reset_smart_input: false, custom_emojis: custom_emojis)
      # |> update(
      #   :smart_input_opts,
      #   &Map.merge(&1, %{
      #     submit_disabled: Bonfire.UI.Common.SmartInput.LiveHandler.should_disable_submit?(socket)
      #   })
      # )
    }
  end

  def handle_event(
        _action,
        _attrs,
        socket
      ) do
    socket
    |> Bonfire.Boundaries.LiveHandler.prepare_assigns()
  end

  # Removed the handle_info handler to avoid conflicts with PersistentLive
end
