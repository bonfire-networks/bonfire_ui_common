defmodule Bonfire.UI.Common.SmartInputLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop user_image, :string, required: true
  # prop target_component, :string
  prop create_activity_type, :atom, default: nil
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: nil
  prop open_boundaries, :boolean, default: false
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop showing_within, :any, default: nil
  prop with_rich_editor, :boolean, default: true, required: false
  prop activity, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: false
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop show_select_recipients, :boolean, default: false
  prop thread_mode, :any, default: nil
  prop page, :any, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop layout_mode, :string, default: nil

  # Classes to customize the smart input appearance
  prop replied_activity_class, :css_class, default: "relative  p-3 bg-base-100 hover:!bg-base-100 hover:!bg-opacity-100 showing_within:smart_input overflow-hidden"

  def mount(socket),
    do: {:ok,
      socket
      |> assign(
        trigger_submit: false,
        uploaded_files: []
      )
      |> allow_upload(:files,
        accept: ~w(.jpg .jpeg .png .gif .svg .tiff .webp .pdf .md .rtf .mp3 .mp4), # make configurable
        max_file_size: 10_000_000, # make configurable, expecially once we have resizing
        max_entries: 10,
        auto_upload: false
        # progress: &handle_progress/3
      )
    } # |> IO.inspect

  def all_smart_input_components do
    Bonfire.Common.Config.get([:ui, :smart_input_components], [post: Bonfire.UI.Social.WritePostContentLive])
  end

  def active_smart_input_component(smart_input_component, create_activity_type) do
    smart_input_component || e(all_smart_input_components(), create_activity_type, nil) || Bonfire.Common.Config.get([:ui, :default_smart_input]) || Bonfire.UI.Social.WritePostContentLive
  end

  def smart_input_name(component) do
    all_smart_input_components()
    |> Keyword.filter(fn {_key, val} -> val==component end)
    |> Keyword.keys()
    |> List.first()
    |> display_name()
  end

  defp display_name(name) do
    name
    |> maybe_to_string()
  end

  def set_smart_input_text(socket, text \\ "\n") do
    socket
    |> maybe_push_event("smart_input:set_body", %{text: text})
  end

  def reset_input(%{assigns: %{showing_within: :thread}} = socket) do
    # debug("THREad")
    socket
    |> set_smart_input_text()
    |> assign_generic(
      activity: nil,
      to_circles: nil,
      reply_to_id: e(socket.assigns, :thread_id, nil),
      to_boundaries: default_boundaries(socket)
      # open_boundaries: false
    )
  end

  def reset_input(%{assigns: %{showing_within: :messages}} = socket) do
    # debug("messages")

    socket
    |> set_smart_input_text()
    |> assign_generic(
      activity: nil,
      smart_input_text: nil
    )
  end

  def reset_input(socket) do
    # debug("VOID")

    socket
    |> set_smart_input_text()
    |> assign_generic(
      reply_to_id: nil,
      thread_id: nil,
      to_circles: nil,
      activity: nil,
      smart_input_text: nil,
      to_boundaries: default_boundaries(socket)
      # open_boundaries: false
    )
  end

  def activity_type_or_reply(assigns) do
    # debug(e(assigns, :reply_to_id, ""), "reply to id")
    # debug(e(assigns, :thread_id, ""), "thread_id")
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :thread_id, "") !="",
    do: "reply",
    else: e(assigns, :create_activity_type, "post")
  end

  # def boundary_ids(preset_boundary, to_boundaries, create_activity_type) do
  #   if is_list(to_boundaries) and length(to_boundaries)>0 do
  #     Enum.map_join(to_boundaries, "\", \"", &elem(&1, 1))
  #   else
  #     if create_activity_type in [:message, "message"],
  #       do: "message",
  #       else: preset_boundary || "public"
  #   end
  # end

  # def boundary_names(preset_boundary, to_boundaries, create_activity_type) do
  #   if is_list(to_boundaries) and length(to_boundaries)>0 do
  #     Enum.map_join(to_boundaries, "\", \"", &elem(&1, 0))
  #   else
  #     if create_activity_type in [:message, "message"],
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

  defp clean_existing(to_boundaries, acl_id) when acl_id in ["public", "local", "mentions"] do
    to_boundaries
    |> Keyword.drop(["public", "local", "mentions"])
  end
  defp clean_existing(to_boundaries, _) do
    to_boundaries
  end

  def handle_event("select_smart_input", %{"component" => component}, socket) do
    {:noreply, socket
      |> assign(smart_input_component: maybe_to_module(component))
    }
  end

  def handle_event("open_boundaries", _params, socket) do
    {:noreply, socket
      |> assign(:open_boundaries, true)
    }
  end

  def handle_event("close_boundaries", _params, socket) do
    {:noreply, socket
      |> assign(:open_boundaries, false)
    }
  end

  def handle_event("select_boundary", %{"id" => acl_id} = params, socket) do
    debug(acl_id, "select_boundary")
    {:noreply, socket
      |> assign(
        :to_boundaries,
        clean_existing(e(socket.assigns, :to_boundaries, []), acl_id)
          ++ [{acl_id, e(params, "name", acl_id)}]
      )
    }
  end

  def handle_event("remove_boundary", %{"id" => acl_id} = _params, socket) do
    debug(acl_id, "remove_boundary")
    {:noreply, socket
      |> assign(
        :to_boundaries,
        e(socket.assigns, :to_boundaries, [])
          |> Keyword.drop([acl_id])
      )
    }
  end

  def handle_event("tagify_add", attrs, socket) do
    handle_event("select_boundary", attrs, socket)
  end

  def handle_event("tagify_remove", attrs, socket) do
    handle_event("remove_boundary", attrs, socket)
  end

  def handle_event("validate", _params, socket) do # for uploads
    {:noreply, socket}
  end
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, reset_input(socket)}
  end


  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers


end
