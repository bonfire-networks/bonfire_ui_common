defmodule Bonfire.UI.Common.SharedDataDanceCase do
  use ExUnit.CaseTemplate
  import Tesla.Mock
  import Untangle
  import Bonfire.UI.Common.Testing.Helpers
  alias Bonfire.Common.TestInstanceRepo

  def a_fake_user!(name, opts \\ []) do
    # repo().delete_all(ActivityPub.Object)
    user = fake_user!("#{name} #{Pointers.ULID.generate()}", %{}, opts)

    [
      user: user,
      username: Bonfire.Me.Characters.display_username(user, true),
      url_on_local:
        "@" <>
          Bonfire.Me.Characters.display_username(user, true) <>
          "@" <> Bonfire.Common.URIs.instance_domain(Bonfire.Me.Characters.character_url(user)),
      canonical_url: Bonfire.Me.Characters.character_url(user),
      friendly_url: Bonfire.Common.URIs.base_url() <> Bonfire.Common.URIs.path(user)
    ]
  end

  def fake_remote!(opts \\ []) do
    TestInstanceRepo.apply(fn -> a_fake_user!("Remote", opts) end)
  end

  setup_all tags do
    Bonfire.Common.Test.Interactive.setup_test_repo(tags)

    on_exit(fn ->
      # this callback needs to checkout its own connection since it
      # runs in its own process
      # :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo())
      # Ecto.Adapters.SQL.Sandbox.mode(repo(), :auto)

      # Object.delete(actor1)
      # Object.delete(actor2)
      :ok
    end)

    [
      local: a_fake_user!("Local"),
      remote: fake_remote!()
    ]
  end
end
