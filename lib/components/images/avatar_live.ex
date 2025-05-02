defmodule Bonfire.UI.Common.AvatarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user_id, :string, default: nil
  prop parent_id, :string, default: nil
  # prop user, :any, default: nil
  prop src, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop comment, :boolean, default: false
  # prop size, :any, default: nil
  prop wrapper_class, :css_class, default: "border-0 avatar !flex"
  prop class, :css_class, default: "w-12 h-12 rounded-lg bg-base-100 h-full"

  prop bg_class, :css_class,
    default: ["h-full flex items-centeer place-conten-center w-full flex-1"]

  prop avatar_fallback, :string, default: nil
  prop title, :string, default: ""
  prop opts, :any, default: %{}

  # def classes(%{class: class}) when not is_nil(class) do
  #   class
  # end

  # def classes(%{viewing_main_object: true}) do
  #   "w-14 h-14 rounded-lg bg-base-200"
  # end

  # def classes(%{comment: true}) do
  #   "w-8 h-8 rounded-lg bg-base-200"
  # end

  # def classes(_) do
  #   "w-12 h-12 md:w-10 md:h-10 rounded bg-base-300"
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
