defmodule Bonfire.UI.Common.MultiselectLive.UserSelectorLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form_input_name, :string, default: nil
  prop label, :string, default: nil
  prop pick_event, :string, default: nil
  prop remove_event, :string, default: nil
  prop selected_options, :any, default: nil
  prop preloaded_options, :any, default: nil
  prop context_id, :string, default: nil
  prop event_target, :any, default: nil
  prop class, :css_class, default: nil
  prop is_editable, :boolean, default: true
  prop type, :any, default: Bonfire.Data.Identity.User

  def users(preloaded_options, context, type) do
    preloaded_options || context[:preloaded_users] || load_users(current_user(context), type)
  end

  def load_users(current_user, type) do
    debug(current_user)

    # TODO: paginate?
    followed =
      if current_user,
        do:
          Bonfire.Social.Follows.list_my_followed(current_user, paginate: false, type: type)
          |> debug()
          # |> e(:edges, [])
          |> Enum.map(&e(&1, :edge, :object, nil)),
        else: []

    debug(followed)

    [{e(current_user, :profile, :name, "Me"), e(current_user, :id, "me")}] ++
      followed
  end
end
