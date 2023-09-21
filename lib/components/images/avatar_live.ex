defmodule Bonfire.UI.Common.AvatarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop parent_id, :string, default: nil
  prop user, :any, default: nil
  prop src, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop comment, :boolean, default: false
  prop size, :any, default: nil
  prop class, :css_class, default: "w-12 h-12 rounded-full bg-base-100 h-full"
  prop bg_class, :css_class, default: ["rounded h-full"]
  prop avatar_fallback, :string, default: nil
  prop title, :string, default: ""
  prop opts, :any, default: %{}

  def animal_avatar(id) do
    # keeps avatars per-user cached
    Cache.maybe_apply_cached(&avatar_face/1, [id])
  end

  defp avatar_face(id) when is_binary(id) do
    Pointers.ULID.encoded_randomness(id)
    |> do_avatar_face()
  end

  defp avatar_face(id) do
    warn(id, "expected an ID for generating an avatar")
    do_avatar_face("random")
  end

  defp do_avatar_face(id) do
    id
    |> AnimalAvatarGenerator.avatar_face(
      # TODO: colors in config
      avatar_colors: ["#801100", "#B62203", "#D73502", "#FC6400", "#FF7500", "#FAC000"]
    )
  end

  def classes(%{class: class}) when not is_nil(class) do
    class
  end

  def classes(%{viewing_main_object: true}) do
    "w-14 h-14 rounded-lg bg-base-200"
  end

  def classes(%{comment: true}) do
    "w-8 h-8 rounded-lg bg-base-200"
  end

  def classes(_) do
    "w-12 h-12 md:w-10 md:h-10 rounded bg-base-300"
  end

  def size(%{size: size}) when not is_nil(size) do
    size
  end

  def size(%{viewing_main_object: true}) do
    48
  end

  def size(%{comment: true}) do
    32
  end

  def size(_) do
    "100%"
  end
end
