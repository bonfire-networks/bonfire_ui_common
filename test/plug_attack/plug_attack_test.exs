defmodule Bonfire.UI.Common.PlugAttackDanceTest do
  use Bonfire.UI.Common.ConnCase, async: false
  use Bonfire.UI.Common.SharedDataDanceCase

  @moduletag :test_instance

  import Untangle
  import Bonfire.Common.Config, only: [repo: 0]
  import Bonfire.UI.Common.SharedDataDanceCase

  alias Bonfire.Common.TestInstanceRepo

  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows
  alias Bonfire.Boundaries.{Circles, Acls, Grants}

  test "attack the signup endpoint", context do
    # on remote instance, try to login to local instance
    TestInstanceRepo.apply(fn ->
      file =
        "../fixtures/credentials_100.txt"
        |> Path.expand(__DIR__)

      Bonfire.UI.Common.PlugAttackTesting.run({"http://localhost:4000/signup", "account"}, file)
      |> IO.puts()
    end)
  end

  test "attack the login endpoint", context do
    # on remote instance, try to login to local instance
    TestInstanceRepo.apply(fn ->
      file =
        "../fixtures/credentials_100.txt"
        |> Path.expand(__DIR__)

      Bonfire.UI.Common.PlugAttackTesting.run("http://localhost:4000/login", file)
      |> IO.puts()
    end)
  end
end
