defmodule Bonfire.UI.Common.SmartInputContainerLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputLive

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop create_object_type, :any, default: nil
  prop smart_input_component, :atom, default: nil
  prop open_boundaries, :boolean, default: false
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop activity, :any, default: nil
  # prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop show_select_recipients, :boolean, default: false
  # prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  # prop without_sidebar, :string, default: nil
  prop reset_smart_input, :boolean, default: false

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

  def update(
        %{smart_input_opts: new_smart_input_opts} = assigns,
        %{assigns: %{smart_input_opts: old_smart_input_opts}} = socket
      )
      when is_map(new_smart_input_opts) and is_map(old_smart_input_opts) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:smart_input_opts, Map.merge(old_smart_input_opts, new_smart_input_opts))}
  end

  # def update(%{set_smart_input_text_if_empty: text} = assigns, %{assigns: %{smart_input_opts: smart_input_opts}} = socket) do
  #   if empty?(e(smart_input_opts, :text, nil) |> debug("texxxt") ) do

  #     SmartInputLive.replace_input_next_time(socket)
  #     SmartInputLive.set(socket,
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
     |> assign(assigns)}
  end

  def do_handle_event("select_smart_input", params, socket) do
    # debug(params)
    # send_self(socket, smart_input_opts: %{open: e(params, :open, nil)})

    opts =
      (maybe_from_json(e(params, "opts", nil)) ||
         e(socket.assigns, :smart_input_opts, []))
      |> Enum.into(%{open: true})
      |> debug("opts")

    to_circles =
      (params["to_circles"] || e(opts, :to_circles, []))
      # |> maybe_from_json_string()
      |> Enum.flat_map(&Enum.map(&1, fn {key, val} -> {key, val} end))
      |> debug("to_circles")

    {:noreply,
     socket
     |> assign(opts)
     |> assign(
       smart_input_component:
         maybe_to_module(e(params, "component", nil) || e(params, "smart_input_component", nil)),
       create_object_type: maybe_to_atom(e(params, "create_object_type", nil)),
       reply_to_id:
         reply_to_param(params) || reply_to_param(opts) || e(socket.assigns, :reply_to_id, nil),
       smart_input_opts: opts,
       activity: nil,
       object: nil,
       activity_inception: "reply_to",
       to_circles:
         (to_circles || e(socket.assigns, :to_circles, []))
         |> debug("to_circles")
     )}
  end

  def do_handle_event(action, params, socket)
      when action in [
             "open_boundaries",
             "close_boundaries",
             "select_boundary",
             "remove_boundary",
             "tagify_add",
             "tagify_remove",
             "remove_circle"
           ] do
    maybe_apply(Bonfire.Boundaries.LiveHandler, :handle_event, [action, params, socket])
  end

  # needed for uploads

  def do_handle_event("validate", %{"html_body" => html_body} = params, socket)
      when is_binary(html_body) do
    debug(params, "validate")

    {
      :noreply,
      socket
      |> assign(
        # to avoid un-reset the input
        reset_smart_input: false
      )
      #  |> update(
      #    :smart_input_opts,
      #    &Map.merge(&1, %{
      #      text: html_body,
      #     #  submit_disabled: false,
      #     #  submit_label: nil
      #      # submit_label: "#{length}/#{max_length}"
      #    })
      #  )
    }

    # end
  end

  def do_handle_event("validate", params, socket) do
    debug(params, "validate without body")

    {:noreply,
     socket
     # to avoid un-reset the input
     |> assign(reset_smart_input: false)}
  end

  def do_handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :files, ref)}
  end

  def do_handle_event("reset", _params, socket) do
    {:noreply, SmartInputLive.reset_input(socket)}
  end

  def max_length do
    default = 2000

    Settings.get([Bonfire.UI.Common.SmartInputLive, :max_length], default)
    |> Types.maybe_to_integer(default)
    |> debug()
  end

  def maybe_from_json_string("{" <> _ = json) do
    json
    |> String.replace(~s(\"), ~s("))
    |> maybe_from_json()
  end

  def maybe_from_json_string(_), do: nil

  def maybe_from_json("{" <> _ = json) do
    with {:ok, data} <- Jason.decode(json) do
      data
    else
      e ->
        warn(e)
        nil
    end
  end

  def maybe_from_json(_), do: nil

  def reply_to_param(%{"reply_to" => "{" <> _ = reply_to}) do
    maybe_from_json(reply_to)
  end

  def reply_to_param(%{"reply_to_id" => reply_to_id}) when is_binary(reply_to_id) do
    reply_to_id
  end

  def reply_to_param(%{"reply_to" => reply_to}) when is_binary(reply_to) do
    reply_to
  end

  def reply_to_param(_) do
    nil
  end

  # def set_smart_input_as(:flat, _), do: :focused
  def set_smart_input_as(:messages, _), do: :focused

  def set_smart_input_as(_, context),
    do: Settings.get([:ui, :smart_input_as], :non_blocking, context)

  # def as(smart_input_opts) do
  #   # FIXME: in some situations we end up with `[:non_blocking, :non_blocking, :non_blocking]`
  #   case e(smart_input_opts |> debug("smart_input_opts"), :as, nil) do
  #     as when is_atom(as) -> as
  #     as_list when is_list(as_list) -> List.last(as_list)
  #   end || :non_blocking
  # end

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
