defmodule Bonfire.UI.Common.MultiselectLive.UserSelectorLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form_input_name, :string, default: nil
  prop label, :string, default: nil
  prop pick_event, :string, default: nil
  prop remove_event, :string, default: nil
  prop selected_options, :any, default: nil
  prop preloaded_options, :any, default: nil
  prop context_id, :string, default: nil

  # FIXME! update no longer works in stateless
  def update(%{preloaded_options: pre} = assigns, socket) when is_list(pre) do
    {:ok,
     assign(
       socket,
       assigns
     )}
  end

  def update(assigns, socket) do
    # debug(userSelectorLive: assigns)

    current_user = current_user(assigns)

    # TODO: paginate
    followed =
      if current_user,
        do:
          Bonfire.Social.Follows.list_my_followed(current_user, paginate: false)
          |> Enum.map(&follow_to_tuple/1),
        else: []

    debug(followed: followed)

    preloaded_options =
      [{e(current_user, :profile, :name, "Me"), e(current_user, :id, "me")}] ++
        followed

    {:ok,
     assigns_merge(
       socket,
       assigns,
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
