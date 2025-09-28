defmodule Bonfire.UI.Common.SmartInput.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  def switch_smart_input_type(_type, js \\ %JS{}) do
    js
    |> maximize()
    |> JS.push("Bonfire.UI.Common.SmartInput:select_smart_input",
      value: %{
        opts: encode_opts(%{open: true})
      }
    )
  end

  def show_main(js \\ %JS{}) do
    js
    |> JS.show(to: "#composer_container")
    |> maximize()
    |> JS.push("Bonfire.UI.Common.SmartInput:select_smart_input",
      value: %{
        opts: encode_opts(%{open: true})
      }
    )
  end

  def open(js \\ %JS{}, opts \\ nil) do
    opts = opts || %{}
    # add open: true to opts
    opts = Map.merge(opts, %{open: true})

    js
    |> JS.show(to: "#composer_container")
    |> maximize()
    # |> show_main(opts)
    |> maybe_push_opts("Bonfire.UI.Common.SmartInput:select_smart_input", opts)

    # |> maybe_push_opts("Bonfire.UI.Common.SmartInput:select_smart_input", %{open: true})
  end

  def open_type(js \\ %JS{}, component, opts \\ nil) do
    js
    |> show_main()
    |> JS.show(to: ".smart_input_show_on_open")
    |> JS.push("Bonfire.UI.Common.SmartInput:select_smart_input",
      value: %{
        component: component,
        opts: encode_opts(opts)
      }
    )
  end

  def handle_event("reset_to_default", params, socket) do
    replace_input_next_time(assigns(socket))

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      to_circles: [],
      reply_to_id: e(assigns(socket), :thread_id, nil),
      to_boundaries: Bonfire.Boundaries.default_boundaries(assigns(socket)),
      smart_input_opts: %{
        input_status: nil,
        create_object_type: nil,
        open: false,
        text_suggestion: nil,
        recipients_editable: false,
        text: nil,
        title: nil,
        cw: nil
      }
    )

    {:noreply, do_extra_reset_input(socket)}
  end

  # close_smart_input should reset the state to ensure it's clean for next use
  def close_smart_input(js \\ %JS{}) do
    js
    |> JS.hide(to: ".smart_input_show_on_open")
    |> JS.push("Bonfire.UI.Common.SmartInput:select_smart_input",
      value: %{
        opts: encode_opts(%{open: false})
      }
    )
  end

  # confirm_close_smart_input is used with modals
  def confirm_close_smart_input(js \\ %JS{}, reusable_modal_id) do
    # First close the modal, then reset the smart input state
    js
    |> JS.push("close",
      target: "##{reusable_modal_id || "modal"}"
    )
    # Reset state after closing modal
    |> close_smart_input()
  end

  def submitting(js \\ %JS{}) do
    js
    |> JS.add_class("hidden", to: "#main_smart_input_button .toggle_button")
    |> JS.remove_class("hidden", to: "#main_smart_input_button .submitting_icon")
    |> JS.add_class("btn-disabled", to: "#main_smart_input_button")
    |> JS.set_attribute({"disabled", "true"}, to: "#main_smart_input_button")
    |> minimize(%{input_status: :submit})
  end

  def reset_submitting(js \\ %JS{}, to \\ "#main_smart_input_button") do
    js
    |> JS.remove_class("hidden", to: "#{to} .toggle_button")
    |> JS.add_class("hidden", to: "#{to} .submitting_icon")
    |> JS.remove_class("btn-disabled", to: to)
    |> JS.remove_attribute("disabled", to: to)
  end

  def minimize(js \\ %JS{}, opts \\ %{}) do
    js
    |> JS.add_class("translate-y-100",
      to: "#smart_input_container",
      transition: {"transition-transform duration-300", "translate-y-0", "translate-y-100"}
    )
    # Always remove avoid-scroll class from mobile devices to restore scrolling
    |> JS.remove_class("avoid-scroll", to: ".is-container-mobile")
    # |> JS.show(to: ".smart_input_show_on_minimize")
    |> maybe_push_opts(
      "Bonfire.UI.Common.SmartInput:select_smart_input",
      Map.put(opts, :open, false)
    )
  end

  def maximize(js \\ %JS{}) do
    js
    |> JS.remove_class("translate-y-100",
      to: "#smart_input_container",
      transition: {"transition-transform duration-300", "translate-y-100", "translate-y-0"}
    )
    # Always add avoid-scroll class to mobile devices to hide scrollbar
    |> JS.add_class("avoid-scroll", to: ".is-container-mobile")

    # |> JS.hide(to: ".smart_input_show_on_minimize")
    # |> JS.push("Bonfire.UI.Common.SmartInput:select_smart_input",
    #   value: %{
    #     opts: encode_opts(%{open: true})
    #   }
    # )
  end

  # def handle_event("set", %{"smart_input_as" => smart_input_as}, socket) do
  #   # note: only works with phx-target being the smart input, in other cases use `set/2` instead
  #   {:noreply,
  #    socket
  #    |> assign(smart_input_as: maybe_to_atom(smart_input_as) |> debug("smart_input_as"))}
  # end

  def handle_event("select_smart_input", params, socket) do
    debug(params, "params")

    push_event(socket, "mentions-suggestions", %{mentions: e(params, "mentions", [])})

    # Check if we should merge with existing opts
    should_merge = Map.get(params, "merge_opts", false)

    # Parse options from params
    parsed_opts =
      maybe_from_json(e(params, "opts", nil)) || e(assigns(socket), :smart_input_opts, [])

    parsed_opts = input_to_atoms(parsed_opts)

    # Get existing smart_input_opts from socket
    existing_opts = e(assigns(socket), :smart_input_opts, %{})

    # Only default to open: true if not explicitly set in params
    open_value = if Map.has_key?(parsed_opts, :open), do: parsed_opts.open, else: true

    # Merge opts or use new ones
    opts =
      if should_merge do
        # Merge with existing opts, but new values take precedence
        Map.merge(existing_opts, parsed_opts)
        |> Map.put(:open, open_value)
      else
        # Use new opts directly
        parsed_opts
        |> Enum.into(%{open: open_value})
      end
      |> debug("select_smart_input_opts")

    to_circles =
      (params["to_circles"] || e(opts, :to_circles, []))
      |> Enum.flat_map(&Enum.map(&1, fn {key, val} -> {key, val} end))
      |> debug("to_circles")

    # NEW: Process exclude_circles (same structure as to_circles)
    exclude_circles =
      (params["exclude_circles"] || e(opts, :exclude_circles, []))
      |> Enum.flat_map(&Enum.map(&1, fn {key, val} -> {key, val} end))
      |> debug("exclude_circles")

    to_boundaries =
      List.wrap(params["to_boundaries"] || e(opts, :to_boundaries, []))
      |> debug("input to_boundaries")
      # NOTE: what's going on here??
      |> Enum.flat_map(
        &Enum.map(List.wrap(&1), fn
          {key, val} -> {key, val}
          val -> val
        end)
      )
      |> debug("processed to_boundaries")

    set_assigns =
      [
        smart_input_component:
          maybe_to_module(e(params, "component", nil) || e(params, "smart_input_component", nil)),
        create_object_type:
          e(opts, "create_object_type", nil) || e(params, "create_object_type", nil),
        context_id: e(opts, "context_id", nil) || e(params, "context_id", nil),
        reply_to_id:
          reply_to_param(params) || reply_to_param(opts) || e(assigns(socket), :reply_to_id, nil),
        # FIXME: do not pass everything blindly to smart_input_opts
        smart_input_opts: opts,
        activity: nil,
        object: nil,
        showing_within: e(assigns(socket), :showing_within, nil),
        activity_inception: "reply_to",
        to_boundaries: e(to_boundaries, nil) || e(assigns(socket), :to_boundaries, nil),
        to_circles: to_circles,
        # NEW: Add exclude_circles to assigns
        exclude_circles: exclude_circles,
        mentions: e(opts, "mentions", nil) || e(params, "mentions", [])
      ]
      |> debug("set_assigns")

    {:noreply,
     socket
     |> assign(opts)
     |> assign(set_assigns)
     |> push_event("focus-editor", %{})}
  end

  def handle_event("remove_data", _params, socket) do
    {:noreply,
     assign(socket,
       activity: nil,
       object: nil,
       # default to replying to current thread
       reply_to_id: e(assigns(socket), :thread_id, nil),
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

  def handle_event("validate", params, socket) do
    # Get text from params and text_suggestion from socket.assigns
    text = e(params, "post", "post_content", "html_body", nil)
    # text_suggestion = e(socket.assigns.smart_input_opts, :text_suggestion, "")

    # Check if uploads exist using simplified check
    uploads = e(assigns(socket), :uploads, nil)
    smart_input_opts = e(assigns(socket), :smart_input_opts, nil)
    input_status = smart_input_opts[:input_status]

    # Determine if submit should be disabled
    input_status =
      if input_status != :submit and
           (not is_nil(text) || String.trim(to_string(text || "")) != "" ||
              (uploads && uploads[:files] && uploads.files.entries != [])) do
        :draft
      else
        input_status
      end
      |> debug("drafting in validation")

    # Update the socket's own smart_input_opts
    socket =
      socket
      |> assign(
        reset_smart_input: false,
        smart_input_opts:
          Enum.into(
            %{
              input_status: input_status
            },
            e(assigns(socket), :smart_input_opts, %{})
          )
      )

    # ATTEMPTED FIX: Instead of sending a complete new set of assigns that might override
    # context data like activity, we only update the component's smart_input_opts property
    # directly using update_component
    # maybe_update_smart_input_component(
    #   Bonfire.UI.Common.SmartInputContainerLive,
    #   :smart_input,
    #   :smart_input_opts,
    #   fn existing_opts ->
    #     Map.merge(existing_opts, %{input_status: drafting? && :draft})
    #   end
    # )

    # Return the updated socket directly
    {:noreply, socket}
  end

  # # Helper function to update a component's property without replacing the entire component state
  # defp maybe_update_smart_input_component(component, id, property, update_fn) do
  #   try do
  #     maybe_send_update(component, id, %{property => update_fn.(%{})})
  #   rescue
  #     _ -> nil
  #   catch
  #     _ -> nil
  #   end
  # end

  # def smart_input_opts(context_or_args) do
  #     cond do
  #       # From direct assigns map
  #       is_map(context_or_args) && Map.has_key?(context_or_args, :smart_input_opts) ->
  #         context_or_args.smart_input_opts

  #       # From socket
  #       is_map(context_or_args) && Map.has_key?(context_or_args, :assigns) ->
  #         e(context_or_args.assigns, :smart_input_opts, %{})

  #       # From context map
  #       _ ->
  #         e(context_or_args, :smart_input_opts, %{})
  #     end
  #   end

  # def should_disable_submit?(context_or_args) do
  #   # Extract smart_input_opts based on the input type
  #   smart_input_opts = smart_input_opts(context_or_args)

  #   if is_map(smart_input_opts) && Map.has_key?(smart_input_opts, :input_status) do
  #     smart_input_opts.input_status != :draft
  #   else
  #     # Default to disabled if we can't determine state
  #     true
  #   end
  # end

  def handle_event("select", params, socket) do
    Bonfire.Boundaries.LiveHandler.handle_event("select", params, socket)
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    # Safely cancel upload
    debug(e(socket, :uploads, :files, "CAZZ"), "CAZZZZ")
    debug(e(socket, :files, "CAZZ"), "CAZZZZ2")
    try do
      # Cancel the upload - check if uploads exist first
      socket = Phoenix.LiveView.cancel_upload(socket, :files, ref)

      smart_input_opts = e(assigns(socket), :smart_input_opts, nil)

      # Check if we should disable the submit button
      text = e(socket.assigns.smart_input_opts, :text, nil)
      # text_suggestion = e(socket.assigns.smart_input_opts, :text_suggestion, "")

      # Check if there are any remaining uploads
      uploads = e(assigns(socket), :uploads, nil)

      input_status = smart_input_opts[:input_status]

      # Determine if submit should be disabled
      input_status =
        if input_status != :submit and
             (not is_nil(text) || String.trim(to_string(text || "")) != "" ||
                (uploads && e(uploads, :files, :entries, []) != [])) do
          :draft
        else
          input_status
        end
        |> debug("drafting in validation")

      # Update the socket first
      socket =
        socket
        |> assign(reset_smart_input: false)
        |> update(
          :smart_input_opts,
          &Map.merge(&1, %{input_status: input_status})
        )

      # Return the updated socket directly
      {:noreply, socket}
    rescue
      e ->
        warn(e, "Error in cancel-upload handler")
        {:noreply, socket}
    catch
      e ->
        warn(e, "Error in cancel-upload handler")
        {:noreply, socket}
    end
  end

  def handle_event("toggle-cover-image", %{"ref" => ref}, socket) do
    current_cover = e(assigns(socket), :selected_cover, nil)
    debug(current_cover, "CACCA")
    # Toggle the cover image - if it's already selected, deselect it, otherwise select it
    new_cover = if current_cover == ref, do: nil, else: ref
    debug(new_cover, "CACCA")

    {:noreply, assign(socket, selected_cover: new_cover)}
  end

  @doc """
  Cancel all pending uploads for the smart input
  This is useful when closing the composer or resetting it
  """
  def cancel_all_uploads(socket) do
    # Only cancel uploads that are not yet completed
    with uploads when not is_nil(uploads) <- e(socket.assigns, :uploads, nil),
         true <- uploads[:files] != nil,
         entries <- uploads.files.entries,
         pending_entries <- Enum.reject(entries, &(&1.done? or &1.cancelled?)) do
      if pending_entries != [] do
        debug("Cancelling #{length(pending_entries)} pending uploads")

        Enum.reduce(pending_entries, socket, fn entry, acc_socket ->
          try do
            Phoenix.LiveView.cancel_upload(acc_socket, :files, entry.ref)
          rescue
            _error -> acc_socket
          catch
            _error -> acc_socket
          end
        end)
      else
        debug("No pending uploads to cancel")
        socket
      end
    else
      _ -> socket
    end
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
        opts: do_encode_opts(opts |> debug("push smart_input_opts")),
        # Flag to indicate we want to merge with existing opts
        merge_opts: true
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

  def set_smart_input_opts(socket, %{} = opts_to_set) do
    # Make sure smart_input_opts is a map
    current_opts =
      set_smart_input_opts(
        assigns(socket),
        assigns(socket)[:smart_input_opts] || %{},
        %{} = opts_to_set
      )
  end

  def set_smart_input_opts(context, current_opts, %{} = opts_to_set) do
    # Make sure smart_input_opts is a map
    current_opts = if is_list(current_opts), do: Enum.into(current_opts, %{}), else: current_opts

    # Use our consistent merger function
    set(
      context,
      %{smart_input_opts: merge_smart_input_opts(current_opts, opts_to_set)}
    )
  end

  @doc """
  Merges new opts with existing ones, maintaining important state
  Use this helper for consistent merging across functions
  """
  def merge_smart_input_opts(existing_opts, new_opts)
      when is_map(existing_opts) and is_map(new_opts) do
    # Start with existing options
    Map.merge(existing_opts, new_opts)
  end

  @doc """
  Open the composer by setting assigns
  """
  def assign_open(context, assigns_to_set \\ %{}) do
    # Make sure smart_input_opts is a map
    current_opts = assigns_to_set[:smart_input_opts] || %{}
    current_opts = if is_list(current_opts), do: Enum.into(current_opts, %{}), else: current_opts

    # Use our consistent merger function
    set(
      context,
      Enums.merge_as_map(
        assigns_to_set,
        %{smart_input_opts: merge_smart_input_opts(current_opts, %{open: true})}
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

    # Get current smart_input_opts if available
    current_opts = e(socket_or_context, :assigns, :smart_input_opts, %{})

    set(
      socket_or_context,
      Enums.deep_merge(set_assigns,
        smart_input_opts:
          merge_smart_input_opts(current_opts, %{text_suggestion: text, open: true}),
        reset_smart_input: false
      )
      |> debug("params")
    )
  end

  def set_smart_input_text(socket_or_context, text \\ "\n") do
    # Get current smart_input_opts if available
    current_opts = e(socket_or_context, :assigns, :smart_input_opts, %{})

    replace_input_next_time(socket_or_context)

    # Merge with existing opts to preserve other properties
    set(
      socket_or_context,
      smart_input_opts: merge_smart_input_opts(current_opts, %{text: text, open: true}),
      reset_smart_input: false
    )

    socket_or_context
  end

  def replace_input_next_time(socket_or_context) do
    set(socket_or_context, reset_smart_input: true)
  end

  def reset_input(%{assigns: %{showing_within: :thread}} = socket) do
    # debug("THREad")
    replace_input_next_time(assigns(socket))

    # Set default reset state
    default_opts = %{
      input_status: nil,
      open: false,
      text_suggestion: nil,
      text: nil,
      title: nil,
      cw: nil
    }

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      to_circles: [],
      reply_to_id: e(assigns(socket), :thread_id, nil),
      to_boundaries: Bonfire.Boundaries.default_boundaries(assigns(socket)),
      smart_input_opts: default_opts
    )

    do_extra_reset_input(socket)
  end

  def reset_input(%{assigns: %{showing_within: :messages}} = socket) do
    # debug("messages")
    replace_input_next_time(socket)

    # Set default reset state
    default_opts = %{
      input_status: nil,
      open: false,
      text_suggestion: nil,
      text: nil,
      cw: nil
    }

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      to_circles: [],
      smart_input_opts: default_opts
    )

    do_extra_reset_input(socket)
  end

  def reset_input(socket) do
    replace_input_next_time(socket)

    # Set default reset state
    default_opts = %{
      input_status: nil,
      open: false,
      text_suggestion: nil,
      text: nil,
      create_object_type: nil,
      cw: nil
    }

    set(socket,
      # avoid double-reset
      reset_smart_input: false,
      activity: nil,
      smart_input_component: nil,
      to_circles: [],
      reply_to_id: e(assigns(socket), :thread_id, nil),
      thread_id: nil,
      to_boundaries: Bonfire.Boundaries.default_boundaries(assigns(socket)),
      smart_input_opts: default_opts
    )

    do_extra_reset_input(socket)
  end

  defp do_extra_reset_input(socket) do
    debug(
      "=== DO_EXTRA_RESET_INPUT CALLED ===#{inspect(Process.info(self(), :current_stacktrace))}"
    )

    try do
      socket
      |> push_event("js-exec-attr-event", %{to: "#main_smart_input_button", attr: "phx-reset"})
      |> push_event("smart_input:reset", %{})
      # |> reset_submitting()
      |> cancel_all_uploads()
    rescue
      error ->
        debug(error, "Error during extra reset input")
        socket
    catch
      error ->
        debug(error, "Caught error during extra reset input")
        socket
    end
  end

  def toggle_expanded(js \\ %JS{}, target, btn, class) when is_binary(class) do
    # TODO: document
    js
    |> JS.toggle(to: target)
    #  seems toggle as in and out classes we could use: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html#toggle/1
    |> toggle_class(btn, class)
  end

  def show_expanded(js \\ %JS{}, target, btn, class) when is_binary(class) do
    # TODO: document
    js
    |> JS.show(to: target)
    #  seems toggle as in and out classes we could use: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html#toggle/1
    |> toggle_class(btn, class)
  end

  def toggle_class(js \\ %JS{}, btn, class) when is_binary(class) do
    # TODO: document
    js
    |> JS.toggle_class(class, to: btn)

    #  seems toggle as in and out classes we could use: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html#toggle/1
    # |> JS.remove_class(
    #   class,
    #   to: btn <> "." <> class
    # )
    # |> JS.add_class(
    #   class,
    #   to: btn <> ":not(." <> class <> ")"
    # )
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
