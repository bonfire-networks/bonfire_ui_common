defmodule Bonfire.UI.Common.SmartInputInlineLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: []
  prop smart_input_opts, :any, required: false
  prop showing_within, :any, default: nil
  prop activity, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop show_select_recipients, :boolean, default: false
  prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  prop without_sidebar, :string, default: nil

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
         max_entries: 10,
         auto_upload: false
         # progress: &handle_progress/3
       )}

  defdelegate handle_event(action, attrs, socket),
    to: Bonfire.UI.Common.SmartInputContainerLive

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  defdelegate handle_params(params, attrs, socket),
    to: Bonfire.UI.Common.LiveHandlers
end