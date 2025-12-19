defmodule Bonfire.UI.Common.RateLimitDanceTest do
  use Bonfire.UI.Common.ConnCase, async: false
  use Bonfire.UI.Common.SharedDataDanceCase

  #   @moduletag :fixme
  @moduletag :test_instance

  import Untangle
  import Bonfire.Common.Config, only: [repo: 0]
  import Bonfire.UI.Common.SharedDataDanceCase

  alias Bonfire.Common.TestInstanceRepo

  test "attack the sign up endpoint", context do
    # Process.put([:bonfire, :env], :dev)

    # on_exit(fn ->
    #   Process.delete([:bonfire, :env])
    # end)

    # on remote instance, try to sign up to local instance
    TestInstanceRepo.apply(fn ->
      file =
        "../fixtures/credentials_100.txt"
        |> Path.expand(__DIR__)

      # Use very slow RPM (30 req/min = 2 seconds per request)
      # Each "request" is actually GET + POST, so this is 60 HTTP requests/min total
      Bonfire.UI.Common.RateLimit.Testing.run(
        {"http://localhost:4000/signup", "account"},
        file,
        "30"
      )
      |> IO.puts()
    end)
  end

  test "attack the login endpoint", context do
    Process.put([:bonfire, :env], :dev)

    on_exit(fn ->
      Process.delete([:bonfire, :env])
    end)

    # on remote instance, try to login to local instance
    TestInstanceRepo.apply(fn ->
      file =
        "../fixtures/credentials_100.txt"
        |> Path.expand(__DIR__)

      # Use very slow RPM (30 req/min) to avoid hitting GET rate limits while testing POST throttling
      Bonfire.UI.Common.RateLimit.Testing.run(
        "http://localhost:4000/login",
        file,
        "30"
      )
      |> IO.puts()
    end)
  end
end
