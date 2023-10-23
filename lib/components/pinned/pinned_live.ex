defmodule Bonfire.UI.Common.PinnedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop page_title, :string, default: "Highlights"
  prop feed, :list, default: []
  prop page_info, :list, default: []
  prop user, :any, default: nil
  prop selected_tab, :string, default: "highlights"

  def update(assigns, socket) do
    current_user = current_user(assigns) || current_user(socket.assigns)
    feed = Bonfire.Social.Pins.list_by(
      assigns.user,
      object_type: e(assigns, :object_types, []),
      current_user: current_user
    )

    edges =
      for %{edge: %{} = edge} <- e(feed, :edges, []),
          do: %{activity: edge |> Map.put(:verb, %{verb: "Pinned"})}

    {:ok,
     socket
     |> assign(
       page: "Highlights",
       selected_tab: e(assigns, :selected_tab, "highlights"),
       page_title: "Highlights",
       current_user: current_user,
       feed_id: :pins,
       feed: edges || [],
       loading: false,
       page_info: e(feed, :page_info, [])
     )}
  end

  # def handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end

  # def handle_params(%{} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      current_user: Fake.user_live()
  #    )}
  # end

  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers

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
          __MODULE__
          # &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
