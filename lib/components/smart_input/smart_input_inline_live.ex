defmodule Bonfire.UI.Common.SmartInputInlineLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputContainerLive

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: :smart_input
  prop activity, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil

  prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  prop without_sidebar, :string, default: nil
  prop smart_input_as, :atom, default: nil

  def mount(socket),
    do:
      {:ok,
       socket
       |> assign(
         trigger_submit: false,
         uploaded_files: []
       )
       |> SmartInputContainerLive.setup_uploads()}

  defdelegate handle_event(action, attrs, socket),
    to: SmartInputContainerLive

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  defdelegate handle_params(params, attrs, socket),
    to: Bonfire.UI.Common.LiveHandlers
end
