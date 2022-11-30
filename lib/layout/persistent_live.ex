defmodule Bonfire.UI.Common.PersistentLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Common.SmartInputLive

  def mount(_params, session, socket) do
    assigns = input_to_atoms(session)
    # |> info("assigns from session")

    # subscribe
    assigns[:context][:csrf_token]
    |> info("session_topic")
    |> pubsub_subscribe(socket)

    {:ok,
     socket
     |> assign(Map.drop(assigns, [:context]))
     |> assign(:__context__, assigns[:context])
     |> assign_new(:showing_within, fn -> nil end)
     |> assign_new(:context_id, fn -> nil end)
     |> assign_new(:reply_to_id, fn -> nil end)
     |> assign_new(:create_object_type, fn -> nil end)
     |> assign_new(:to_boundaries, fn -> [] end)
     |> assign_new(:to_circles, fn -> [] end)
     |> assign_new(:smart_input_opts, fn -> nil end)
     |> assign_new(:showing_within, fn -> nil end)
     |> assign_new(:show_select_recipients, fn -> false end)
     |> assign_new(:thread_mode, fn -> nil end)
     |> assign_new(:page, fn -> nil end)
     |> assign_new(:page_title, fn -> nil end)
     |> assign_new(:selected_tab, fn -> nil end)
     |> assign_new(:activity_inception, fn -> nil end)
     |> assign_new(:title_open, fn -> nil end)
     |> assign_new(:title_prompt, fn -> nil end)
     |> assign_new(:preloaded_recipients, fn -> nil end)
     |> assign_new(:without_sidebar, fn -> nil end)
     |> assign_new(:without_widgets, fn -> nil end)
     |> assign_new(:nav_header, fn -> nil end)
     #  |> assign_new(:nav_items, fn -> nil end)
     |> assign_new(:sidebar_widgets, fn -> [] end)
     #  |> assign_new(:page_header_aside, fn -> nil end)
     #  |> assign_new(:custom_page_header, fn -> nil end)
     |> info("socket prepared via session"), layout: false}
  end

  @doc """
  Set assigns for the persistent view
  """
  def set(context, assigns) do
    assigns = persistent_assigns_filter(assigns)
    maybe_send(context, assigns) || send_self(assigns)
  end

  def maybe_set(context, assigns) do
    maybe_send(context, persistent_assigns_filter(assigns))
  end

  defp persistent_assigns_filter(assigns) do
    assigns
    |> Map.new()
    |> Map.take([
      :showing_within,
      :reply_to_id,
      :context_id,
      :create_object_type,
      :smart_input_component,
      :thread_mode,
      :without_sidebar,
      :without_widgets,
      :to_boundaries,
      :to_circles,
      :smart_input_opts,
      :nav_header,
      # :nav_items,
      # :custom_page_header,
      # :page_header_aside,
      :sidebar_widgets,
      :page,
      :page_title,
      :selected_tab
    ])
    |> Map.put(:__context__, Map.merge(assigns[:__context__] || %{}, %{sticky: true}))
  end

  def maybe_send(context, assigns) do
    debug(assigns, "send persistent assigns")

    case e(context, :sticky, nil) do
      true ->
        debug("already in PersistentLive process")
        false

      _ ->
        debug("send to PersistentLive liveview process")

        if e(context, :csrf_token, nil) do
          e(context, :csrf_token, nil)
          |> pubsub_broadcast({:assign, assigns})

          true
        else
          debug(
            context,
            "no csrf_token available in context so can't send to sticky smart input LV (if used)"
          )

          :skip
        end
    end
  end

  def handle_info({:assign, {:smart_input, assigns}}, socket) do
    debug("forward assigns from PersistentLive to the smart input stateful component")

    assigns
    |> Map.new()
    |> Map.put_new(:smart_input_component, nil)
    |> maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, ...)

    {:noreply, socket}
  end

  def handle_info({:assign, assigns}, socket) do
    {:noreply,
     assigns
     |> Map.new()
     |> Map.put(:smart_input_component, nil)
     |> debug("set received assigns for PersistentLive")
     |> assign(socket, ...)}
  end

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
