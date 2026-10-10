defmodule Bonfire.UI.Common.AvatarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user_id, :string, default: nil
  prop parent_id, :string, default: nil
  # prop user, :any, default: nil
  prop src, :any, default: nil
  prop showing_within, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop comment, :boolean, default: false
  # prop size, :any, default: nil
  prop wrapper_class, :css_class, default: "border-0 avatar !flex w-full"
  prop class, :css_class, default: "size-12 rounded-full bg-base-100 h-full"
  # show the design-system avatar ring (0.7px inset primary red)
  prop ring, :boolean, default: false

  prop bg_class, :css_class,
    default: ["h-full flex items-centeer place-conten-center w-full flex-1"]

  prop avatar_fallback, :string, default: nil
  prop fallback_class, :css_class, default: "size-5 opacity-50"
  prop title, :string, default: ""
  prop opts, :any, default: %{}
  prop disable_lazy, :boolean, default: true
  prop is_remote, :boolean, default: true

  @doc "Returns the image source to use when a user has no uploaded avatar."
  def generated_avatar_src(user_id, context \\ nil)

  def generated_avatar_src(user_id, context) when is_binary(user_id) and user_id != "" do
    case generated_avatar_paths(context) do
      [] ->
        "/gen_avatar/#{user_id}"

      avatar_paths ->
        Enum.at(avatar_paths, :erlang.phash2(user_id, length(avatar_paths)))
    end
  end

  def generated_avatar_src(_, _), do: nil

  def initials(name) when is_binary(name) and name != "" do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  def initials(_), do: ""

  defp generated_avatar_paths(context) do
    Settings.get([__MODULE__, :generated_avatar_paths], [],
      context: context,
      name: l("Generated avatar paths"),
      description: l("Static image paths to use for users without a profile picture.")
    )
    |> List.wrap()
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
  end

  # def classes(%{class: class}) when not is_nil(class) do
  #   class
  # end

  # def classes(%{viewing_main_object: true}) do
  #   "size-14 rounded-box bg-base-200"
  # end

  # def classes(%{comment: true}) do
  #   "size-8 rounded-box bg-base-200"
  # end

  # def classes(_) do
  #   "size-12 md:size-10 rounded bg-base-300"
  # end

  # def size(%{size: size}) when not is_nil(size) do
  #   size
  # end

  # def size(%{viewing_main_object: true}) do
  #   48
  # end

  # def size(%{comment: true}) do
  #   32
  # end

  # def size(_) do
  #   "100%"
  # end
end
