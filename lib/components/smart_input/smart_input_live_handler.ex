defmodule Bonfire.UI.Common.SmartInput.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  def switch_smart_input_type(_type, js \\ %JS{}) do
    js
    |> maximize()
  end

  def show_main(js \\ %JS{}, _opts \\ nil) do
    js
    |> JS.hide(to: "#extra_boundaries")
    |> JS.hide(to: "#boundaries_picker")
    |> JS.hide(to: "#roles_detail")
    |> JS.show(to: "#composer_container")
    |> maximize()
  end

  def open(js \\ %JS{}, opts \\ nil) do
    js
    |> show_main(opts)
    |> maybe_push_opts("select_smart_input", opts)
  end

  def open_type(js \\ %JS{}, component, create_object_type, opts \\ nil) do
    js
    |> show_main(opts)
    |> JS.show(to: ".smart_input_show_on_open")
    |> JS.push("select_smart_input",
      value: %{
        component: component,
        create_object_type: create_object_type,
        opts: encode_opts(opts)
      }
    )
  end

  def close_smart_input(js \\ %JS{}) do
    js
    |> JS.hide(to: ".smart_input_show_on_open")
    |> JS.push("reset")
  end

  def confirm_close_smart_input(js \\ %JS{}, reusable_modal_id) do
    # Bonfire.UI.Common.OpenModalLive.close(reusable_modal_id)
    js
    |> JS.push("close",
      target: "##{reusable_modal_id || "modal"}"
    )
    |> close_smart_input()
  end

  def minimize(js \\ %JS{}) do
    js
    # transition: {"transition-all duration-200", "h-auto w-auto", "h-[40px] w-[20rem]"}, time: 200
    |> JS.hide(to: ".smart_input_modal")
    |> JS.hide(to: ".smart_input_show_on_open")
    |> JS.hide(to: "#extra_boundaries")
    |> JS.hide(to: "#boundaries_picker")
    |> JS.hide(to: "#roles_detail")
    |> JS.hide(
      to: ".smart_input_backdrop",
      transition: {"transition-opacity duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.show(to: ".smart_input_show_on_minimize")
  end

  def maximize(js \\ %JS{}) do
    js
    |> JS.show(to: ".smart_input_show_on_open")
    |> JS.hide(to: ".smart_input_show_on_minimize")
    |> JS.show(
      to: ".smart_input_backdrop",
      transition: {"transition-opacity duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: ".smart_input_modal",
      display: "flex",
      transition: {"transition-all duration-200", "h-[40px] w-[20rem]", "h-auto w-auto"},
      time: 200
    )
  end

  # def handle_event("set", %{"smart_input_as" => smart_input_as}, socket) do
  #   # note: only works with phx-target being the smart input, in other cases use `set/2` instead
  #   {:noreply,
  #    socket
  #    |> assign(smart_input_as: maybe_to_atom(smart_input_as) |> debug("smart_input_as"))}
  # end

  def handle_event("select_smart_input", params, socket) do
    push_event(socket, "mentions-suggestions", %{mentions: e(params, "mentions", [])})

    opts =
      (maybe_from_json(e(params, "opts", nil)) ||
         e(socket.assigns, :smart_input_opts, []))
      |> input_to_atoms()
      |> Enum.into(%{open: true})
      |> debug("opts")

    to_circles =
      (params["to_circles"] || e(opts, :to_circles, []))
      |> Enum.flat_map(&Enum.map(&1, fn {key, val} -> {key, val} end))
      |> debug("to_circles")

    to_boundaries =
      (params["to_boundaries"] || e(opts, :to_boundaries, []))
      |> Enum.flat_map(
        &Enum.map(&1, fn
          {key, val} -> {key, val}
        end)
      )
      |> debug("to_boundaries")

    set_assigns =
      [
        smart_input_component:
          maybe_to_module(e(params, "component", nil) || e(params, "smart_input_component", nil)),
        create_object_type:
          maybe_to_atom(
            e(opts, "create_object_type", nil) || e(params, "create_object_type", nil)
          ),
        context_id: e(opts, "context_id", nil) || e(params, "context_id", nil),
        reply_to_id:
          reply_to_param(params) || reply_to_param(opts) || e(socket.assigns, :reply_to_id, nil),
        # FIXME: do not pass everything blindly to smart_input_opts
        smart_input_opts: opts,
        activity: nil,
        object: nil,
        activity_inception: "reply_to",
        to_boundaries: e(to_boundaries, nil) || e(socket.assigns, :to_boundaries, nil),
        to_circles: to_circles,
        mentions: e(opts, "mentions", nil) || e(params, "mentions", [])
      ]
      |> debug("set_assigns")

    {:noreply,
     socket
     |> assign(opts)
     |> assign(set_assigns)}
  end

  def handle_event("remove_data", _params, socket) do
    {:noreply,
     assign(socket,
       activity: nil,
       object: nil,
       # default to replying to current thread
       reply_to_id: e(socket, :assigns, :thread_id, nil),
       thread_id: nil
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

  def handle_event("validate", _params, socket) do
    # debug(params, "socket2")

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

  def handle_event("select", params, socket) do
    Bonfire.Boundaries.LiveHandler.handle_event("select", params, socket)
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :files, ref)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, reset_input(socket)}
  end

  def handle_event(_, _params, socket) do
    {:noreply,
     socket
     # to avoid un-reset the input
     |> assign(reset_smart_input: false)}
  end

  defp maybe_push_opts(js \\ %JS{}, event, opts)

  defp maybe_push_opts(js, event, %{} = opts) when opts != %{} do
    js
    |> JS.push(event,
      value: %{
        opts: do_encode_opts(opts |> debug("opppp"))
      }
    )
  end

  defp maybe_push_opts(js, _event, opts) do
    warn(opts, "no smart_input_opts")
    js
  end

  defp encode_opts(%{} = opts) when opts != %{}, do: do_encode_opts(opts)
  defp encode_opts(_), do: nil
  defp do_encode_opts(opts), do: Jason.encode!(Map.drop(opts || %{}, [:text]))

  @doc """
  Open the composer by setting assigns
  """
  def assign_open(context, assigns) do
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

  def open_with_text_suggestion(text, set_assigns, socket_or_context) do
    replace_input_next_time(socket_or_context)

    set(
      socket_or_context,
      Enums.deep_merge(set_assigns,
        smart_input_opts: [text_suggestion: text, open: true],
        reset_smart_input: false
      )
      |> debug("params")
    )
  end

  def set_smart_input_text(socket_or_context, text \\ "\n") do
    # maybe_push_event(socket, "smart_input:set_body", %{text: text})
    replace_input_next_time(socket_or_context)
    set(socket_or_context, smart_input_opts: %{text: text, open: true}, reset_smart_input: false)
    socket_or_context
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
      to_boundaries: Bonfire.Boundaries.default_boundaries(socket.assigns),
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
      to_boundaries: Bonfire.Boundaries.default_boundaries(socket.assigns),
      smart_input_opts: %{
        open: false,
        text_suggestion: nil,
        text: nil
      }
    )

    socket
  end

  def toggle_expanded(js \\ %JS{}, target, btn, class) when is_binary(btn) and is_binary(class) do
    # TODO: document
    js
    |> JS.toggle(to: target)
    #  seems toggle as in and out classes we could use: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html#toggle/1
    |> JS.remove_class(
      class,
      to: btn <> "." <> class
    )
    |> JS.add_class(
      class,
      to: btn <> ":not(." <> class <> ")"
    )
  end

  def max_length do
    default = 2000

    Settings.get([Bonfire.UI.Common.SmartInputLive, :max_length], default)
    |> Types.maybe_to_integer(default)

    # |> debug()
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

  # def set_smart_input_as(context),
  #   do: Settings.get([:ui, :smart_input_as], :non_blocking, context)

  # def as(smart_input_opts) do
  #   # FIXME: in some situations we end up with `[:non_blocking, :non_blocking, :non_blocking]`
  #   case e(smart_input_opts |> debug("smart_input_opts"), :as, nil) do
  #     as when is_atom(as) -> as
  #     as_list when is_list(as_list) -> List.last(as_list)
  #   end || :non_blocking
  # end

  def all_smart_input_components do
    # Bonfire.Common.Config.get([:ui, :smart_input_components],
    #   post: Bonfire.UI.Social.WritePostContentLive
    # )
    Bonfire.UI.Common.SmartInputModule.smart_input_modules_types()
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

  def activity_type_or_reply(assigns) do
    if e(assigns, :reply_to_id, "") != "" or e(assigns, :thread_id, "") != "",
      do: "reply",
      else: e(assigns, :create_object_type, "post")
  end

  # def boundary_ids(boundary_preset, to_boundaries, create_object_type) do
  #   if is_list(to_boundaries) and length(to_boundaries)>0 do
  #     Enum.map_join(to_boundaries, "\", \"", &elem(&1, 1))
  #   else
  #     if create_object_type in [:message, "message"],
  #       do: "message",
  #       else: boundary_preset || "public"
  #   end
  # end

  # def boundary_names(boundary_preset, to_boundaries, create_object_type) do
  #   if is_list(to_boundaries) and length(to_boundaries)>0 do
  #     Enum.map_join(to_boundaries, "\", \"", &elem(&1, 0))
  #   else
  #     if create_object_type in [:message, "message"],
  #       do: "Message",
  #       else: boundary_preset || "Public"
  #   end
  # end
end
