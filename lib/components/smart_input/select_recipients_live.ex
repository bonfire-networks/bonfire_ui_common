defmodule Bonfire.UI.Common.SelectRecipientsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop target_component, :string
  prop preloaded_recipients, :list, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop context_id, :string, default: nil
  prop showing_within, :atom, default: nil
  prop implementation, :any, default: :live_select
  prop label, :string, default: nil
  prop class, :string, default: "w-full h-10 input rounded-full select_recipients_input"

  def do_handle_event("live_select_change", %{"id" => live_select_id, "text" => search}, socket) do
    # current_user = current_user(socket)

    Bonfire.Me.Users.search(search)
    |> results_for_multiselect()
    |> maybe_send_update(LiveSelect.Component, live_select_id, options: ...)

    {:noreply, socket}
  end

  def do_handle_event(
        "multi_select",
        %{data: %{"field" => field, "id" => id, "username" => username}},
        socket
      ) do
    # TODO: support selecting more than one?
    {:noreply,
     socket
     |> update(maybe_to_atom(field) |> debug("f"), fn current_to_circles ->
       (List.wrap(current_to_circles) ++ [{username, id}])
       |> debug("v")
     end)}
  end

  def results_for_multiselect(results) do
    results
    |> Enum.map(fn
      # %Bonfire.Data.AccessControl.Circle{} = circle ->
      #   {e(circle, :named, :name, nil) || e(circle, :sterotyped, :named, :name, nil),
      #    %{id: e(circle, :id, nil), field: :to_circles}}

      user ->
        {"#{e(user, :profile, :name, nil)} - #{e(user, :character, :username, nil)}",
         %{
           id: e(user, :id, nil),
           field: :to_circles,
           icon: Media.avatar_url(user),
           username: e(user, :character, :username, nil)
         }}
    end)
    # Filter to remove any nils
    |> Enum.filter(fn {name, _} -> name != nil end)
    |> debug()
  end
end
