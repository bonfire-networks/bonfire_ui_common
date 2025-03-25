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
      "w-full h-10 input !border-none !border-b !border-base-content/10 !rounded-none select_recipients_input"

  prop is_editable, :boolean, default: false


  def handle_event("live_select_change", %{"id" => live_select_id, "text" => search}, socket) do
    # current_user = current_user(assigns(socket))
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
    |> maybe_send_update(LiveSelect.Component, live_select_id, options: ...)

    {:noreply, socket}
  end

  def handle_event(
        "multi_select",
        %{data: %{"field" => field, "id" => id, "username" => username}},
        socket
      ) do
    {:noreply,
     socket
     |> update(maybe_to_atom(field) |> debug("f"), fn current_to_circles ->
       (List.wrap(current_to_circles) ++ [{id, username}])
       |> debug("v")
     end)}
  end

  def handle_event(
        "multi_select",
        %{data: data},
        socket
      )
      when is_list(data) do
    first = List.first(data)

    field =
      maybe_to_atom(e(first, :field, :to_circles))
      |> debug("field")

    updated =
      Enum.map(
        data,
        &{id(&1), e(&1, "username", nil)}
      )
      |> filter_empty([])
      |> debug("new value")

    if updated != e(assigns(socket), field, nil) |> debug("existing") do
      # Update local state first
      socket = assign(socket, field, Enum.uniq(updated))

      # Track selected fields globally
      socket = assign_global(socket,
        _already_live_selected_:
          Enum.uniq(e(assigns(socket), :__context, :_already_live_selected_, []) ++ [field])
      )

      # Send targeted update to the parent container
      # This uses the special update handler in SmartInputContainerLive that only
      # updates the specific field without touching other fields
      maybe_send_update(Bonfire.UI.Common.SmartInputContainerLive, :smart_input,
      %{
        update_field: field,
        field_value: Enum.uniq(updated),
        preserve_state: true
      })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
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
