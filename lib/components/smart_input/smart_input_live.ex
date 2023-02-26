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
  prop smart_input_opts, :map, default: %{}
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
  prop reset_smart_input, :boolean, default: false

  prop uploads, :any, default: nil
  prop uploaded_files, :any, default: nil
  prop trigger_submit, :boolean, default: nil

  # Classes to customize the smart input appearance
  prop replied_activity_class, :css_class,
    default:
      "items-center !bg-base-300 opacity-80 !flex-row order-first !p-3 before:border-neutral-content/80 mr-[40px]"

  def all_smart_input_components do
    Bonfire.Common.Config.get([:ui, :smart_input_components],
      post: Bonfire.UI.Social.WritePostContentLive
    )
  end

  def active_smart_input_components(smart_input_component, create_object_type) do
    # debug(smart_input_component, "smart_input_component")
    # debug(create_object_type, "create_object_type")
    List.wrap(
      smart_input_component ||
        components_by_type(create_object_type) ||
        active_smart_input_component(smart_input_component, create_object_type)
    )
    |> debug("components")
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
        smart_input_opts: Map.merge(assigns[:smart_input_opts] || %{}, %{open: true})
      )
    )
  end

  # def open_and_reset_if_empty(text, socket_assigns, set_assigns) do
  #   # if empty?(e(socket_assigns, :smart_input_opts, :text, nil) |> debug()), do: replace_input_next_time(socket_assigns)
  #   set(socket_assigns, set_smart_input_text_if_empty: text)
  #   set(socket_assigns[:__context__], set_assigns)
  # end

  @doc """
  Set assigns in the smart input from anywhere in the app (whether using a live component or sticky live view)
  """
  def set(context, assigns) do
    debug(assigns, "set assigns")

    Bonfire.UI.Common.PersistentLive.maybe_send(context, {:smart_input, assigns}) ||
      maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, assigns)
  end

  def open_smart_input_with_text_suggestion(text, set_assigns, socket_or_context) do
    # TODO: only trigger if using Quill as editor?
    # maybe_push_event(socket, "smart_input:set_body", %{text: text})
    replace_input_next_time(socket_or_context)

    set(
      socket_or_context,
      set_assigns ++
        [smart_input_opts: %{text_suggestion: text, open: true}, reset_smart_input: false]
    )
  end

  def set_smart_input_text(socket, text \\ "\n") do
    # TODO: only trigger if using Quill as editor?
    # maybe_push_event(socket, "smart_input:set_body", %{text: text})
    replace_input_next_time(socket)
    set(socket, smart_input_opts: %{text: text, open: true}, reset_smart_input: false)
    socket
  end

  def replace_input_next_time(socket_or_context) do
    set(socket_or_context, reset_smart_input: true)
  end

  def reset_input(%{assigns: %{showing_within: :thread}} = socket) do
    # debug("THREad")
    replace_input_next_time(socket.assigns)

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      to_circles: [],
      reply_to_id: e(socket.assigns, :thread_id, nil),
      to_boundaries: default_boundaries(socket),
      smart_input_opts: %{
        open: false,
        text_suggestion: nil,
        text: nil
      }
    )

    socket
  end

  def reset_input(%{assigns: %{showing_within: :messages}} = socket) do
    # debug("messages")
    replace_input_next_time(socket)

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      to_circles: [],
      smart_input_opts: %{
        open: false,
        text_suggestion: nil,
        text: nil
      }
    )

    socket
  end

  def reset_input(socket) do
    replace_input_next_time(socket)

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      create_object_type: nil,
      smart_input_component: nil,
      to_circles: [],
      reply_to_id: e(socket.assigns, :thread_id, nil),
      thread_id: nil,
      to_boundaries: default_boundaries(socket),
      smart_input_opts: %{
        open: false,
        text_suggestion: nil,
        text: nil
      }
    )

    socket
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
