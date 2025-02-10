defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop reply_to_id, :any, default: nil
  prop as_icon, :boolean, default: false
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop open_boundaries, :boolean, default: false
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop mentions, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: :smart_input
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
    if module_enabled?(Bonfire.Files.VideoUploader, socket),
      do:
        maybe_setup_uploads(
          socket,
          Bonfire.Common.Utils.maybe_apply(
            Bonfire.Files.VideoUploader,
            :max_file_size,
            []
          )
        ),
      else: maybe_setup_uploads(socket, 20)
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
        Bonfire.Common.Settings.get(
          [Bonfire.UI.Common.SmartInputLive, :max_uploads],
          :instance,
          current_user(socket)
        ),
      auto_upload: false
      # progress: &handle_progress/3
    )
  end

  def update(
        %{smart_input_opts: new_smart_input_opts} = assigns,
        %{assigns: %{smart_input_opts: old_smart_input_opts}} = socket
      )
      when is_map(new_smart_input_opts) and is_map(old_smart_input_opts) do
    # Load custom emojis
    custom_emojis =
      Bonfire.Files.EmojiUploader.list(assigns(socket))
      |> Enum.map(fn {shortcode, emoji} ->
        %{
          name: emoji.label,
          shortcodes: [shortcode],
          url: emoji.url
        }
      end)
      |> Jason.encode!()
      |> debug("CAZZ")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:custom_emojis, custom_emojis)
     |> assign(smart_input_opts: Map.merge(old_smart_input_opts, new_smart_input_opts))
     |> Bonfire.Boundaries.LiveHandler.prepare_assigns()}
  end

  def update(assigns, socket) do
    # Load custom emojis
    custom_emojis =
      Bonfire.Files.EmojiUploader.list(assigns(socket))
      |> Enum.map(fn {shortcode, emoji} ->
        %{
          name: emoji.label,
          shortcodes: [shortcode],
          url: emoji.url
        }
      end)
      |> Jason.encode!()

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(:custom_emojis, custom_emojis)
      |> Bonfire.Boundaries.LiveHandler.prepare_assigns()
      # TODO: only trigger if module enabled ^
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
end
