defmodule Bonfire.UI.Common.MultiselectLive.UserSelectorLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any, default: :multi_select
  prop form_input_name, :any, default: nil
  prop label, :string, default: nil
  prop pick_event, :string, default: nil
  prop remove_event, :string, default: nil
  prop selected_options, :any, default: nil
  prop preloaded_options, :any, default: nil
  prop context_id, :string, default: nil
  prop event_target, :any, default: nil
  prop class, :string, default: nil
  prop is_editable, :boolean, default: true
  prop type, :any, default: Bonfire.Data.Identity.User
  prop implementation, :atom, default: nil
  prop mode, :atom, default: :single

  def users(preloaded_options, context, type) do
    preloaded_options || context[:preloaded_options][type] ||
      load_users(current_user(context), type)
  end

  def load_users(current_user, Bonfire.Data.Identity.User = type) do
    [{e(current_user, :profile, :name, "Me"), e(current_user, :id, "me")}] ++
      load_followed(current_user, type)
  end

  def load_users(current_user, type) do
    (load_favs(current_user, type) ++ load_followed(current_user, type))
    |> Enum.uniq_by(&id/1)
  end

  def load_followed(current_user, type) do
    # TODO: paginate?
    if current_user,
      do:
        Common.Utils.maybe_apply(
          Bonfire.Social.Graph.Follows,
          :list_my_followed,
          [current_user, paginate: false, type: type]
        )
        # |> debug()
        # |> e(:edges, [])
        |> Enum.map(&e(&1, :edge, :object, nil)),
      else: []
  end

  def load_favs(current_user, type) do
    # TODO: paginate?
    if current_user,
      do:
        Common.Utils.maybe_apply(
          Bonfire.Social.Likes,
          :list_my,
          current_user: current_user,
          paginate: false,
          object_type: type
        )
        # |> debug()
        # |> debug()
        # |> e(:edges, [])
        |> Enum.map(&e(&1, :edge, :object, nil)),
      else: []
  end
end
