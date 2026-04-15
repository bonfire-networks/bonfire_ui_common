defmodule Bonfire.UI.Common.SmartInputInlineLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputContainerLive
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  @embed_reply_dom_id :inline_reply
  def embed_reply_dom_id, do: @embed_reply_dom_id

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: :smart_input
  prop activity, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  # prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop event_target, :any, default: nil

  # prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  # prop without_sidebar, :string, default: nil

  def mount(socket),
    do:
      {:ok,
       socket
       |> SmartInputContainerLive.maybe_setup_uploads()}

  def update(assigns, socket) do
    dom_id =
      to_string(assigns[:id] || assigns[:reply_to_id] || assigns[:context_id] || "default")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:composer_dom_id, dom_id)}
  end

  defdelegate handle_event(action, attrs, socket),
    to: SmartInputContainerLive
end
