defmodule Bonfire.UI.Common.SelectRecipientsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop preloaded_recipients, :list, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop context_id, :string, default: nil
  prop showing_within, :atom, default: nil
  prop implementation, :any, default: :live_select
  prop label, :string, default: nil
  prop event_target, :any, default: nil
  prop mode, :atom, default: :tags

  prop class, :string,
    default:
      "w-full h-10 input !border-none !border-b !border-base-content/20 !rounded-none select_recipients_input"

  prop is_editable, :boolean, default: false

  # Clear LiveSelect when to_circles is reset to empty
  def update(%{to_circles: []} = assigns, socket) do
    send_update(LiveSelect.Component,
      id: "multi_select_select_recipient_multiselect_live_select_component",
      value: []
    )

    {:ok, assign(socket, assigns)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  #   _target" => ["multi_select",
  #    "Elixir.Bonfire.UI.Common.SelectRecipientsLive_empty_selection"],
  #   "multi_select" => %{
  #     "Elixir.Bonfire.UI.Common.SelectRecipientsLive_empty_selection" => "",
  #     "Elixir.Bonfire.UI.Common.SelectRecipientsLive_text_input" => "",
  #     "_unused_Elixir.Bonfire.UI.Common.SelectRecipientsLive_text_input" => ""
  #   }
  # } @ bonfire_ui_common/lib/live_handlers.ex:453 @ Bonfire.UI

  def handle_event(
        "change",
        %{
          "_target" => ["multi_select", "select_recipient_multiselect_empty_selection"],
          "multi_select" => %{
            "_unused_select_recipient_multiselect_text_input" => _,
            "select_recipient_multiselect_empty_selection" => "",
            "select_recipient_multiselect_text_input" => text_input
          }
        } = _params,
        socket
      ) do
    # Simple handler like CustomizeBoundaryLive - just ignore empty selection events
    # LiveSelect will handle clearing through other mechanisms
    {:noreply, socket}
  end

  # Handle LiveSelect user selection - dynamic field names (like CustomizeBoundaryLive)
  def handle_event(
        "change",
        %{"_target" => ["multi_select", field_name], "multi_select" => multi_select_data} =
          params,
        socket
      )
      when is_map_key(multi_select_data, field_name) and
             is_list(:erlang.map_get(field_name, multi_select_data)) do
    debug(params, "LiveSelect recipient selection")
    user_data = multi_select_data[field_name]
    selected_recipients = decode_selected_recipients(user_data)

    # Convert to the expected format for to_circles
    to_circles =
      selected_recipients
      |> Enum.map(fn recipient ->
        {e(recipient, :id, nil), e(recipient, :username, nil)}
      end)
      |> Enum.reject(fn {id, _} -> is_nil(id) end)

    debug(to_circles, "Converted to_circles format")

    # Update local state and parent
    socket = assign(socket, :to_circles, to_circles)

    maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, %{
      update_field: :to_circles,
      field_value: to_circles,
      preserve_state: true
    })

    {:noreply, socket}
  end

  # Handle LiveSelect clear selection - dynamic field names (like CustomizeBoundaryLive)
  def handle_event(
        "change",
        %{"_target" => ["multi_select", field_name], "multi_select" => multi_select_data} =
          params,
        socket
      )
      when is_map_key(multi_select_data, field_name) do
    case {String.ends_with?(field_name, "_empty_selection"), multi_select_data[field_name]} do
      {true, ""} ->
        debug(params, "LiveSelect clearing selection")
        # Clear the selection
        socket = assign(socket, :to_circles, [])

        maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, %{
          update_field: :to_circles,
          field_value: [],
          preserve_state: true
        })

        {:noreply, socket}

      _ ->
        debug(params, "Unhandled clear event")
        {:noreply, socket}
    end
  end

  # Catch-all handler for other change event patterns
  def handle_event("change", _params, socket) do
    {:noreply, socket}
  end

  # [debug] attrs: %{
  #   "field" => "multi_select_select_recipient_multiselect",
  #   "id" => "multi_select_select_recipient_multiselect_live_select_component",
  #   "text" => "ni"
  # }
  def handle_event("live_select_change", %{"id" => live_select_id, "text" => search}, socket)
      when is_binary(search) do
    debug(search, "LiveSelect autocomplete search")
    handle_recipient_search(search, live_select_id, socket)
  end

  # Handle recipient search for autocomplete - use provided live_select_id
  defp handle_recipient_search(search, live_select_id, socket) when byte_size(search) >= 2 do
    search_results = do_recipient_search(search)
    maybe_send_update(LiveSelect.Component, live_select_id, options: search_results)
    {:noreply, socket}
  end

  defp handle_recipient_search(_search, _live_select_id, socket) do
    {:noreply, socket}
  end

  # Search for users (same as CustomizeBoundaryLive pattern)
  defp do_recipient_search(search) do
    Bonfire.Common.Utils.maybe_apply(
      Bonfire.Me.Users,
      :search,
      [search]
    )
    |> Enum.map(fn
      %Needle.Pointer{activity: %{object: user}} -> user
      other -> other
    end)
    |> results_for_multiselect()
  end

  # def handle_event("live_select_change", params, socket) do
  #     IO.inspect(params, label: "live_select_change params")
  #     {:noreply, socket}
  # end

  # def handle_event(
  #       "multi_select",
  #       %{data: %{"field" => field, "id" => id, "username" => username}},
  #       socket
  #     ) do
  #   {:noreply,
  #    socket
  #    |> update(maybe_to_atom(field) |> debug("f"), fn current_to_circles ->
  #      (List.wrap(current_to_circles) ++ [{id, username}])
  #      |> debug("v")
  #    end)}
  # end

  # def handle_event(
  #       "multi_select",
  #       %{data: data},
  #       socket
  #     )
  #     when is_list(data) do
  #   first = List.first(data)

  #   field =
  #     maybe_to_atom(e(first, :field, :to_circles))
  #     |> debug("field")

  #   updated =
  #     Enum.map(
  #       data,
  #       &{id(&1), e(&1, "username", nil)}
  #     )
  #     |> filter_empty([])
  #     |> debug("new value")

  #   if updated != e(assigns(socket), field, nil) |> debug("existing") do
  #     # Update local state first
  #     socket = assign(socket, field, Enum.uniq(updated))

  #     # Track selected fields globally
  #     socket =
  #       assign_global(socket,
  #         _already_live_selected_:
  #           Enum.uniq(e(assigns(socket), :__context, :_already_live_selected_, []) ++ [field])
  #       )

  #     # Send targeted update to the parent container
  #     # This uses the special update handler in SmartInputContainerLive that only
  #     # updates the specific field without touching other fields
  #     maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, %{
  #       update_field: field,
  #       field_value: Enum.uniq(updated),
  #       preserve_state: true
  #     })

  #     {:noreply, socket}
  #   else
  #     {:noreply, socket}
  #   end
  # end

  # Handle empty multi_select (when all tags are cleared)
  # def handle_event("multi_select", %{data: []}, socket) do
  #   field = :to_circles

  #   # Update local state
  #   socket = assign(socket, field, [])

  #   # Send targeted update to the parent container
  #   maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input, %{
  #     update_field: field,
  #     field_value: [],
  #     preserve_state: true
  #   })

  #   {:noreply, socket}
  # end

  # Decode selected recipients from LiveSelect JSON format (similar to CustomizeBoundaryLive)
  defp decode_selected_recipients(json_data) when is_list(json_data) do
    json_data
    |> Enum.map(&decode_single_recipient/1)
    |> Enum.reject(&is_nil/1)
  end

  defp decode_selected_recipients(_), do: []

  defp decode_single_recipient(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> format_decoded_recipient(data)
      {:error, _} -> nil
    end
  end

  defp decode_single_recipient(data) when is_map(data) do
    format_decoded_recipient(data)
  end

  defp decode_single_recipient(_), do: nil

  defp format_decoded_recipient(data) do
    %{
      id: data["id"] || data[:id],
      username: data["username"] || data[:username],
      name: data["name"] || data[:name] || "Unnamed",
      icon: data["icon"] || data[:icon]
    }
  end

  def results_for_multiselect(results) do
    results
    |> Enum.map(fn
      # %Bonfire.Data.AccessControl.Circle{} = circle ->
      #   {e(circle, :named, :name, nil) || e(circle, :sterotyped, :named, :name, nil),
      #    %{id: e(circle, :id, nil), field: :to_circles}}

      user ->
        name = e(user, :profile, :name, nil)
        username = e(user, :character, :username, nil)

        if is_nil(name) and is_nil(username) do
          nil
        else
          {"#{name} - #{username}",
           %{
             id: id(user),
             field: :to_circles,
             name: name,
             icon: Media.avatar_url(user),
             username: username
           }}
        end
    end)
    # Filter to remove any nils
    |> Enum.reject(&is_nil/1)
    # show only the first 4 results
    # |> Enum.take(4)
    |> debug()
  end
end
