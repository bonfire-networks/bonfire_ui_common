defmodule Bonfire.UI.Common.DataHelpers do
  use Bonfire.Common.Utils
  import Bonfire.Me.Fake

  @remote_instance "https://mocked.local"
  @remote_actor @remote_instance <> "/users/karen"
  # @remote_username "karen@mocked.local"
  @local_actor "alice"

  def local_activity_json_to(to \\ @remote_actor)

  def local_activity_json_to(to) when is_list(to) do
    local_user = fake_user!(@local_actor)
    local_activity_json(local_user, to)
  end

  def local_activity_json_to(to) do
    local_activity_json_to([to])
  end

  def local_activity_json(local_user, to) do
    {:ok, local_actor} = ActivityPub.Federator.Adapter.get_actor_by_id(local_user.id)

    %{
      actor: local_actor.ap_id,
      data: %{"type" => "Create"},
      to: to
      # local: true
    }
  end

  def activity_json(actor) do
    %{"actor" => actor, "to" => [ActivityPub.Config.public_uri()]}
  end

  def remote_activity_json() do
    activity_json(@remote_actor)
  end

  def remote_activity_json(actor, to, extra \\ %{}) do
    context = "blabla"

    object =
      Map.merge(
        %{
          "id" => @remote_instance <> "/pub/" <> Pointers.ULID.autogenerate(),
          "content" => "content",
          "type" => "Note",
          "published" => "2015-02-10T15:00:00Z"
        },
        extra
      )

    %{
      type: "Create",
      actor: actor,
      context: context,
      object: object,
      to: to,
      local: false,
      additional: %{
        "id" => @remote_instance <> "/pub/" <> Pointers.ULID.autogenerate(),
        "published" => "2015-02-10T15:10:00Z"
      }
    }
  end

  def local_actor_ids(to) when is_list(to), do: Enum.map(to, &local_actor_ids/1)
  def local_actor_ids(nil), do: fake_user!(@local_actor) |> local_actor_ids()

  def local_actor_ids(%Bonfire.Data.Identity.User{id: id}),
    do: ActivityPub.Federator.Adapter.get_actor_by_id(id) ~> local_actor_ids()

  def local_actor_ids(%{ap_id: ap_id}), do: ap_id
  def local_actor_ids(ap_id) when is_binary(ap_id), do: ap_id

  def remote_activity_json_to(to \\ nil)

  def remote_activity_json_to(to) do
    {:ok, actor} = ActivityPub.Actor.get_cached_or_fetch(ap_id: @remote_actor)

    local_actor_ids(to)
    |> info("local_actor_ids")
    |> remote_activity_json(actor.ap_id, ...)
  end

  def receive_remote_activity_to(to) when not is_list(to),
    do: receive_remote_activity_to([to])

  def receive_remote_activity_to(to) do
    {:ok, actor} = ActivityPub.Actor.get_cached_or_fetch(ap_id: @remote_actor)
    recipient_actors = Enum.map(to, &recipient/1)
    params = remote_activity_json(actor, recipient_actors)

    with {:ok, activity} <- ActivityPub.create(params),
         do: Bonfire.UI.Common.Incoming.receive_activity(activity)
  end

  defp recipient(%{id: _} = recipient) do
    ActivityPub.Actor.get_cached!(pointer: recipient.id).ap_id
  end

  defp recipient(%{ap_id: actor}) do
    actor
  end

  defp recipient(actor) do
    actor
  end

  def remote_actor_json(actor \\ @remote_actor) do
    %{
      "id" => actor,
      "type" => "Person"
    }
  end

  def remote_actor_user(actor_uri \\ @remote_actor) do
    {:ok, actor} = ActivityPub.Actor.get_cached_or_fetch(ap_id: actor_uri)
    {:ok, user} = Bonfire.Me.Users.by_username(actor.username)
    user
  end

  def reject_or_no_recipients?(activity) do
    case activity do
      {:reject, _} -> true
      {:ok, %{to: []}} -> true
      {:ok, %{"to" => []}} -> true
      _ -> false
    end
  end
end
