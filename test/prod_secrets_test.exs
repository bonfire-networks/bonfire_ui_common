defmodule Bonfire.UI.Common.ProdSecretsTest do
  @moduledoc """
  In prod the app refuses to start when `SECRET_KEY_BASE`, `SIGNING_SALT` or `ENCRYPTION_SALT` is missing, even when `CI` or `MIX_QUIET` happen to be set (they must not stand in for a secret). With all three set, the runtime config loads.

  Runs `config/runtime.exs` for the prod env in a separate `mix run`, so no config of this test run is touched.
  """
  use ExUnit.Case, async: false

  @moduletag :slow
  @secrets ~w(SECRET_KEY_BASE SIGNING_SALT ENCRYPTION_SALT)

  # prints one line per case: `<missing secret or "none">:<ok|raised: message>`
  @script """
  secrets = ~w(SECRET_KEY_BASE SIGNING_SALT ENCRYPTION_SALT)
  # what a CI or build environment sets, and what must not stand in for a secret
  System.put_env("CI", "true")
  System.put_env("MIX_QUIET", "1")
  System.put_env("DATABASE_URL", "ecto://postgres:postgres@localhost/not_used")
  Enum.each(secrets, &System.delete_env(&1))

  load = fn missing ->
    Enum.each(secrets -- [missing], &System.put_env(&1, "a-secret-set-for-this-case"))
    Enum.each(missing |> List.wrap(), &System.delete_env/1)

    result =
      try do
        Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
        "ok"
      rescue
        e -> "raised: " <> String.replace(Exception.message(e), "\\n", " ")
      end

    IO.puts("RESULT " <> to_string(missing) <> ":" <> result)
  end

  Enum.each(secrets, load)
  load.(nil)
  """

  test "a missing secret stops the prod config from loading, with CI and MIX_QUIET set" do
    {out, _status} =
      System.cmd("mix", ["run", "--no-start", "--no-deps-check", "-e", @script],
        cd: Path.expand("../../..", __DIR__),
        env: [{"MIX_ENV", "test"}, {"MIX_QUIET", "1"}],
        stderr_to_stdout: true
      )

    results =
      out
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "RESULT "))
      |> Map.new(fn "RESULT " <> line ->
        [name, result] = String.split(line, ":", parts: 2)
        {name, result}
      end)

    # control: with all three set, the config loads, so a raise below is about the missing secret
    assert results[""] == "ok", out

    for secret <- @secrets do
      assert results[secret] =~ "raised",
             "#{secret} missing did not stop startup: #{inspect(results[secret])}"

      assert results[secret] =~ secret
    end
  end
end
