defmodule Bonfire.UI.Common.MultiselectLive.UserSelectorLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form_input_name, :string
  prop label, :string
  prop pick_event, :string
  prop remove_event, :string
  prop selected_options, :any
  prop preloaded_options, :any
  prop context_id, :string

  # FIXME! update no longer works in stateless
  def update(%{preloaded_options: pre} = assigns, socket) when is_list(pre) do

    {:ok, socket
      |> assign(assigns)}
  end

  def update(assigns, socket) do
    # debug(userSelectorLive: assigns)

    current_user = current_user(assigns)

    followed = if current_user, do: Bonfire.Social.Follows.list_my_followed(current_user, paginate: false) # TODO: paginate
    |> Enum.map(&follow_to_tuple/1), else: []

    debug(followed: followed)

    preloaded_options = [{e(current_user, :profile, :name, "Me"), e(current_user, :id, "me")}] ++ followed

    {:ok, socket
      |> assigns_merge(assigns,
      preloaded_options: preloaded_options
      )}
  end



  def follow_to_tuple(%{followed_profile: profile}) do
    {profile.name, profile.id}
  end
  def follow_to_tuple(%{follower_profile: profile}) do
    {profile.name, profile.id}
  end


end
