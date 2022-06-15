defmodule Bonfire.UI.Common.AvatarLive do
  use Bonfire.UI.Common.Web, :stateless_component


  prop profile, :any
  prop viewing_main_object, :boolean
  prop comment, :boolean

  def classes(%{viewing_main_object: true}) do
    "w-12 h-12"
  end
  def classes(%{comment: true}) do
    "w-8 h-8"
  end
  def classes(_) do
    "w-10 h-10"
  end

end
