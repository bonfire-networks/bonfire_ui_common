defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Common.SmartInputLive

  def mount(_params, session, socket) do
    assigns =
      input_to_atoms(session)
      |> info("assigns from session")

    # subscribe
    assigns[:context][:csrf_token]
    |> info("session_topic")
    |> pubsub_subscribe(socket)

    {:ok,
     socket
     |> assign(Map.drop(assigns, [:context]))
     |> assign(:__context__, assigns[:context])
     |> assign_new(:context_id, fn -> nil end)
     |> assign_new(:reply_to_id, fn -> nil end)
     |> assign_new(:create_object_type, fn -> nil end)
     |> assign_new(:to_boundaries, fn -> [] end)
     |> assign_new(:to_circles, fn -> [] end)
     |> assign_new(:smart_input_prompt, fn -> nil end)
     |> assign_new(:smart_input_opts, fn -> nil end)
     |> assign_new(:smart_input_as, fn ->
       SmartInputLive.set_smart_input_as(assigns[:thread_mode], assigns)
     end)
     |> assign_new(:hide_smart_input, fn -> false end)
     |> assign_new(:with_rich_editor, fn -> true end)
     |> assign_new(:showing_within, fn -> nil end)
     |> assign_new(:show_select_recipients, fn -> false end)
     |> assign_new(:thread_mode, fn -> nil end)
     |> assign_new(:smart_input_component, fn -> nil end)
     |> assign_new(:page, fn -> nil end)
     |> assign_new(:activity_inception, fn -> nil end)
     |> assign_new(:title_open, fn -> nil end)
     |> assign_new(:title_prompt, fn -> nil end)
     |> assign_new(:preloaded_recipients, fn -> nil end)
     |> assign_new(:without_sidebar, fn -> nil end)
     |> assign_new(:activity, fn -> nil end)
     |> assign_new(:object, fn -> nil end)
     |> info("smart_input_sticky assigns via session"), layout: false}
  end

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event(action, attrs, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_event(
        action,
        attrs,
        socket,
        __MODULE__
      )
end
