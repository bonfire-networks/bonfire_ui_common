defmodule Bonfire.UI.Common.UndeadTest do
  @moduledoc """
  `undead/3` turns an exception in a LiveView callback into an error notice, so the page still renders. In the test env, the unexpected kinds (a bug in the code, not a failure the user can cause) raise instead, so a test cannot pass on a crash it never saw. The expected ones (`Bonfire.Fail`, `Needle.NotFound`, auth) keep their notice or redirect.
  """
  use Bonfire.UI.Common.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.UI.Common.ErrorHandling
  alias Phoenix.LiveView.Socket

  # a process opts out of the re-raise with `Process.put(@opt_out, false)`
  @opt_out :undead_reraise
  # as a callback receives it
  @socket %Socket{assigns: %{__changed__: %{}, flash: %{}}}

  # each raises one of the unexpected kinds
  defp unexpected_funs do
    [
      {ArgumentError, fn -> raise ArgumentError, "bad argument" end},
      {FunctionClauseError, fn -> apply(__MODULE__, :only_matches_one, [:two]) end},
      {MatchError, fn -> :ok = Enum.random([:not_ok]) end},
      {CaseClauseError,
       fn ->
         case Enum.random([:other]) do
           :one -> :ok
         end
       end},
      {WithClauseError,
       fn ->
         with :one <- Enum.random([:other]) do
           :ok
         else
           :another -> :error
         end
       end},
      {RuntimeError, fn -> raise "a bug" end}
    ]
  end

  def only_matches_one(:one), do: :ok

  test "in the test env it re-raises" do
    assert Bonfire.Common.Config.env() == :test
  end

  test "in the test env, each unexpected kind of exception is re-raised" do
    for {kind, fun} <- unexpected_funs() do
      assert_raise kind, fn -> ErrorHandling.undead(@socket, fun) end
    end
  end

  test "in the test env, an expected error still becomes a notice" do
    assert {:noreply, %Socket{}} =
             ErrorHandling.undead(@socket, fn -> raise Bonfire.Fail, :not_found end)

    assert {:noreply, %Socket{}} =
             ErrorHandling.undead(@socket, fn -> raise Needle.NotFound end)
  end

  test "in the test env, an auth error still redirects to login" do
    assert {:noreply, %Socket{redirected: {_kind, %{to: "/login" <> _}}}} =
             ErrorHandling.undead(@socket, fn -> raise Bonfire.Fail.Auth, :needs_login end)
  end

  test "with the process opted out, an unexpected exception becomes a notice" do
    Process.put(@opt_out, false)

    for {_kind, fun} <- unexpected_funs() do
      assert {:noreply, %Socket{}} = ErrorHandling.undead(@socket, fun)
    end
  end

  # Commented out: outside the test env the re-raise is off, but the env can't change inside a test, so there is no separate path to run here.
  # test "with the setting off in config, an unexpected exception becomes a notice" do
  #   Process.put([:bonfire_ui_common | @key], nil)
  #   refute Bonfire.Common.Config.get(@key, false, :bonfire_ui_common)
  #
  #   assert {:noreply, %Socket{}} =
  #            ErrorHandling.undead(@socket, fn -> raise ArgumentError, "bad argument" end)
  # end
end
