defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop smart_input_as, :any, default: nil
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

  def do_handle_event("select_smart_input", params, socket) do
    # send_self(socket, smart_input_opts: [open: e(params, :open, nil)])
    {:noreply,
     assign(socket,
       smart_input_component:
         maybe_to_module(e(params, "component", nil) || e(params, "smart_input_component", nil)),
       create_object_type: maybe_to_atom(e(params, "create_object_type", nil)),
       reply_to_id: SmartInputLive.reply_to_param(params) || e(socket.assigns, :reply_to_id, nil),
       smart_input_opts:
         SmartInputLive.maybe_from_json(e(params, "opts", nil)) ||
           e(socket.assigns, :smart_input_opts, nil),
       activity_inception: "reply_to"
     )}
  end

  def do_handle_event("open_boundaries", _params, socket) do
    {:noreply, assign(socket, :open_boundaries, true)}
  end

  def do_handle_event("close_boundaries", _params, socket) do
    {:noreply, assign(socket, :open_boundaries, false)}
  end

  def do_handle_event("select_boundary", %{"id" => acl_id} = params, socket) do
    debug(acl_id, "select_boundary")

    {:noreply,
     assign(
       socket,
       :to_boundaries,
       SmartInputLive.clean_existing(e(socket.assigns, :to_boundaries, []), acl_id) ++
         [{acl_id, e(params, "name", acl_id)}]
     )}
  end

  def do_handle_event("remove_boundary", %{"id" => acl_id} = _params, socket) do
    debug(acl_id, "remove_boundary")

    {:noreply,
     assign(
       socket,
       :to_boundaries,
       e(socket.assigns, :to_boundaries, [])
       |> Keyword.drop([acl_id])
     )}
  end

  def do_handle_event("tagify_add", attrs, socket) do
    handle_event("select_boundary", attrs, socket)
  end

  def do_handle_event("tagify_remove", attrs, socket) do
    handle_event("remove_boundary", attrs, socket)
  end

  # for uploads
  def do_handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def do_handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :files, ref)}
  end

  def do_handle_event("reset", _params, socket) do
    {:noreply, SmartInputLive.reset_input(socket)}
  end

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
          __MODULE__,
          &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  defdelegate handle_params(params, attrs, socket),
    to: Bonfire.UI.Common.LiveHandlers
end
