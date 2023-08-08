defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  prop reply_to_id, :any, default: nil
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
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil

  # prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
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
       |> assign(
         trigger_submit: false,
         uploaded_files: []
       )
       |> allow_upload(:files,
         # make configurable
         accept: ~w(.jpg .jpeg .png .gif .svg .tiff .webp .pdf .md .rtf .mp3 .mp4),
         # make configurable, expecially once we have resizing
         max_file_size: 10_000_000,
         max_entries: 4,
         auto_upload: false
         # progress: &handle_progress/3
       )}

  def update(
        %{smart_input_opts: new_smart_input_opts} = assigns,
        %{assigns: %{smart_input_opts: old_smart_input_opts}} = socket
      )
      when is_map(new_smart_input_opts) and is_map(old_smart_input_opts) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:smart_input_as, fn ->
       LiveHandler.set_smart_input_as(e(assigns, :__context__, nil) || current_user(assigns))
     end)
     |> assign(smart_input_opts: Map.merge(old_smart_input_opts, new_smart_input_opts))
     |> assign_boundaries()}
  end

  # def update(%{set_smart_input_text_if_empty: text} = assigns, %{assigns: %{smart_input_opts: smart_input_opts}} = socket) do
  #   if empty?(e(smart_input_opts, :text, nil) |> debug("texxxt") ) do

  #     LiveHandler.replace_input_next_time(socket)
  #     LiveHandler.set(socket,
  #       reset_smart_input: false, # don't do it twice
  #       smart_input_opts: smart_input_opts
  #         |> Keyword.put(:text_suggestion, text)
  #         |> Keyword.put(:open, true)
  #     )

  #     {:ok,
  #     socket
  #     }
  #   else
  #     {:ok,
  #     socket
  #     |> assign(assigns)
  #     }
  #   end
  # end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:smart_input_as, fn ->
       LiveHandler.set_smart_input_as(e(assigns, :__context__, nil) || current_user(assigns))
     end)
     |> assign_boundaries()}
  end

  def assign_boundaries({reply, socket}) do
    {reply, socket |> assign_boundaries()}
  end

  def assign_boundaries(socket) do
    to_boundaries =
      Bonfire.Boundaries.boundaries_or_default(e(socket.assigns, :to_boundaries, nil))
      |> debug()

    socket
    |> assign(
      to_boundaries: to_boundaries,
      boundary_preset:
        Bonfire.Boundaries.Web.SetBoundariesLive.boundaries_to_preset(to_boundaries)
    )
  end

  def handle_event(
        action,
        attrs,
        socket
      ) do
    # debug(attrs)

    Bonfire.UI.Common.LiveHandlers.handle_event(
      action,
      attrs,
      socket,
      __MODULE__,
      &LiveHandler.handle_event/3
    )
    |> assign_boundaries()
  end

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  defdelegate handle_params(params, attrs, socket),
    to: Bonfire.UI.Common.LiveHandlers
end
