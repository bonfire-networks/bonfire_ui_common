defmodule Bonfire.UI.Common.SmartInputLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop user_image, :string, required: true
  # prop target_component, :string
  prop create_object_type, :any, default: nil
  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop open_boundaries, :boolean, default: false
  prop smart_input_opts, :any, required: false
  prop showing_within, :any, default: nil
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop show_select_recipients, :boolean, default: false
  prop thread_mode, :any, default: nil
  prop page, :any, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop without_sidebar, :string, default: nil

  prop uploads, :any, default: nil
  prop uploaded_files, :any, default: nil
  prop trigger_submit, :boolean, default: nil

  # Classes to customize the smart input appearance
  prop replied_activity_class, :css_class,
    default: "!m-3 !rounded-md !shadow !bg-base-content/5 !p-3 !overflow-hidden"

  def all_smart_input_components do
    Bonfire.Common.Config.get([:ui, :smart_input_components],
      post: Bonfire.UI.Social.WritePostContentLive
    )
  end

  def active_smart_input_components(smart_input_component, create_object_type) do
    List.wrap(
      smart_input_component ||
        components_by_type(create_object_type) ||
        active_smart_input_component(smart_input_component, create_object_type)
    )
  end

  def active_smart_input_component(smart_input_component, create_object_type) do
    smart_input_component ||
      component_by_type(create_object_type) ||
      Bonfire.Common.Config.get([:ui, :default_smart_input]) ||
      Bonfire.UI.Social.WritePostContentLive

    # |> debug()
  end

  defp component_by_type(create_object_type) when is_atom(create_object_type) do
    e(all_smart_input_components(), create_object_type, nil)
  end

  defp component_by_type(_) do
    nil
  end

  defp components_by_type(create_object_types) when is_list(create_object_types) do
    Enum.map(create_object_types, &component_by_type/1)
  end

  defp components_by_type(create_object_type) do
    component_by_type(create_object_type)
  end

  def smart_input_name(component) do
    all_smart_input_components()
    |> Keyword.filter(fn {_key, val} -> val == component end)
    |> Keyword.keys()
    |> List.first()
    |> display_name()
  end

  defp display_name(name) do
    maybe_to_string(name)
  end

  @doc """
  Open the composer and set assigns
  """
  def open(context, assigns) do
    set(
      context,
      Keyword.merge(assigns,
        smart_input_opts: Keyword.merge(assigns[:smart_input_opts] || [], open: true)
      )
    )
  end

  @doc """
  Set assigns in the smart input from anywhere in the app (whether using a live component or sticky live view)
  """
  def set(context, assigns) do
    Bonfire.UI.Common.PersistentLive.maybe_send(context, {:smart_input, assigns}) ||
      maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, assigns)
  end

  def set_smart_input_text(socket, text \\ "\n") do
    maybe_push_event(socket, "smart_input:set_body", %{text: text})
  end

  def reset_input(%{assigns: %{showing_within: :thread}} = socket) do
    # debug("THREad")
    socket
    |> set_smart_input_text()
    |> assign_generic(
      activity: nil,
      to_circles: [],
      reply_to_id: e(socket.assigns, :thread_id, nil),
      to_boundaries: default_boundaries(socket)

      # open_boundaries: false
    )
  end

  def reset_input(%{assigns: %{showing_within: :messages}} = socket) do
    # debug("messages")

    socket
    |> set_smart_input_text()
    |> assign_generic(activity: nil)
  end

  def reset_input(socket) do
    # debug("VOID")

    socket
    |> set_smart_input_text()
    |> assign_generic(
      reply_to_id: nil,
      thread_id: nil,
      to_circles: [],
      activity: nil,
      to_boundaries: default_boundaries(socket)
      # open_boundaries: false
    )
  end

  def set_smart_input_as(:flat, _), do: :modal

  def set_smart_input_as(_, context),
    do: Settings.get([:ui, :smart_input_as], :floating, context)

  def activity_type_or_reply(assigns) do
    # debug(e(assigns, :reply_to_id, ""), "reply to id")
    # debug(e(assigns, :thread_id, ""), "thread_id")
    if e(assigns, :reply_to_id, "") != "" or e(assigns, :thread_id, "") != "",
      do: "reply",
      else: e(assigns, :create_object_type, "post")
  end

  # def boundary_ids(preset_boundary, to_boundaries, create_object_type) do
  #   if is_list(to_boundaries) and length(to_boundaries)>0 do
  #     Enum.map_join(to_boundaries, "\", \"", &elem(&1, 1))
  #   else
  #     if create_object_type in [:message, "message"],
  #       do: "message",
  #       else: preset_boundary || "public"
  #   end
  # end

  # def boundary_names(preset_boundary, to_boundaries, create_object_type) do
  #   if is_list(to_boundaries) and length(to_boundaries)>0 do
  #     Enum.map_join(to_boundaries, "\", \"", &elem(&1, 0))
  #   else
  #     if create_object_type in [:message, "message"],
  #       do: "Message",
  #       else: preset_boundary || "Public"
  #   end
  # end

  # defp handle_progress(_, entry, socket) do
  #   debug(entry, "progress")
  #   user = current_user(socket)

  #   if entry.done? and entry.valid? and user do
  #     with %{} = uploaded_media <-
  #       maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
  #         # debug(meta, "icon consume_uploaded_entry meta")
  #         Bonfire.Files.upload(nil, user, path)
  #         |> debug("uploaded")
  #       end) do
  #         # debug(uploaded_media)
  #         {:noreply,
  #           socket
  #           |> update(:uploaded_files, &(&1 ++ [uploaded_media]))
  #           |> assign_flash(:info, l "File uploaded!")
  #         }
  #     end
  #   else
  #     {:noreply, socket}
  #   end
  # end

  # def update(%{activity: activity, object: object, reply_to_id: reply_to_id, thread_id: thread_id} = assigns, socket) do
  #   socket = assign(socket, activity: activity, reply_to_id: reply_to_id, thread_id: thread_id)
  #   {:ok, socket
  #   |> assign(assigns)
  #   }
  #   # {:ok, assign(socket, activity_id: activity_id)}
  # end

  # def update(%{activity: activity, object: object} = assigns, socket) do
  #   socket = assign(socket, activity: activity)
  #   {:ok, socket
  #   |> assign(assigns)
  #   }
  #   # {:ok, assign(socket, activity_id: activity_id)}
  # end

  # def update(assigns, socket) do
  #   {:ok, socket |> assign(assigns)}
  # end
end
