defmodule Bonfire.UI.Common.AvatarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :any, default: nil
  prop src, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop comment, :boolean, default: false
  prop size, :any, default: nil
  prop class, :any, default: nil
  prop avatar_fallback, :string, default: avatar_fallback()

  def classes(%{class: class}) when not is_nil(class) do
    class
  end

  def classes(%{viewing_main_object: true}) do
    "w-12 h-12 bg-base-content/5"
  end

  def classes(%{comment: true}) do
    "w-8 h-8 bg-base-content/5"
  end

  def classes(_) do
    "w-10 h-10 bg-base-content/5"
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
