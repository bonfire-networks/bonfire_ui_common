defmodule Bonfire.UI.Common.SharedDataDanceCase do
  use ExUnit.CaseTemplate
  # import Tesla.Mock
  import Untangle
  import Bonfire.UI.Common.Testing.Helpers
  alias Bonfire.Common.TestInstanceRepo

  setup_all tags do
    Bonfire.Common.Test.Interactive.setup_test_repo(tags)

    TestInstanceRepo.apply(fn ->
      ActivityPub.Utils.cache_clear()

      if !Bonfire.Boundaries.Circles.exists?(Bonfire.Boundaries.Circles.get_id!(:local)) do
        info("Seems boundary fixtures are missing on test instance, running now")
        Bonfire.Boundaries.Scaffold.insert()
      end
    end)

    on_exit(fn ->
      # this callback needs to checkout its own connection since it
      # runs in its own process
      # :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo())
      # Ecto.Adapters.SQL.Sandbox.mode(repo(), :auto)

      :ok
    end)

    [
      local: fancy_fake_user!("Local"),
      remote: fancy_fake_user_on_test_instance()
    ]
  end
end
