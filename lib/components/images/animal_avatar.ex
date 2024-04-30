defmodule Bonfire.UI.Common.AnimalAvatar do
  use Bonfire.UI.Common.Web, :function_component

  def render(assigns) do
    # keeps avatars per-user cached
    ~H"""
    <svg
      data-scope="animal_avatar"
      title={@title}
      xmlns="http://www.w3.org/2000/svg"
      version="1.1"
      width="100%"
      height="100%"
      viewBox="0 0 500 500"
    >
      <rect
        :if={@bg_class != ["rounded"]}
        width="500"
        height="500"
        rx="250"
        fill="none"
        class={@bg_class}
      />
      <%= raw(Cache.maybe_apply_cached(&avatar_face/1, [@id])) %>
    </svg>
    """
  end

  def svg(id) when is_binary(id), do: svg(%{id: id})

  def svg(%{} = assigns) do
    assigns
    |> Map.put_new(:title, nil)
    |> Map.put_new(:bg_class, nil)
    |> render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp avatar_face(id) when is_binary(id) do
    if Types.is_ulid?(id) do
      Needle.ULID.encoded_randomness(id)
    else
      id
    end
    |> do_avatar_face()
  end

  defp avatar_face(id) do
    warn(id, "expected an ID for generating an avatar")
    do_avatar_face("random")
  end

  defp do_avatar_face(id) do
    id
    |> AnimalAvatarGenerator.avatar_face(
      # TODO: colours in config
      avatar_colors: ["#801100", "#B62203", "#D73502", "#FC6400", "#FF7500", "#FAC000"]
    )
  end
end
