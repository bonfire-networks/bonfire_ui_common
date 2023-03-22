defmodule Bonfire.UI.Common.SmartInput.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  def handle_event("select_smart_input", params, socket) do
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

  def handle_event(action, params, socket)
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

  def handle_event("validate", %{"html_body" => html_body} = params, socket)
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

  def handle_event("validate", params, socket) do
    debug(params, "validate without body")

    {:noreply,
     socket
     # to avoid un-reset the input
     |> assign(reset_smart_input: false)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :files, ref)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, reset_input(socket)}
  end

  def minimize(js \\ %JS{}) do
    js
    |> JS.hide(to: ".minimizable")
    |> JS.show(to: ".maximizable")
  end

  def maximize(js \\ %JS{}) do
    js
    |> JS.hide(to: ".maximizable")
    |> JS.show(to: ".minimizable")
  end

  # def hide_modal(js \\ %JS{}) do
  #   js
  #   |> JS.hide(transition: "fade-out", to: "#picker")
  #   |> JS.add_class("hidden", to: "#picker")
  # end

  # def show_modal(js \\ %JS{}) do
  #   js
  #   |> JS.show(transition: "fade-in", to: "#picker")
  #   |> JS.remove_class("hidden", to: "#picker")
  # end

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
end
