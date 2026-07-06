defmodule Bonfire.UI.Common.OverloadShedPlugTest do
  # async: false — mutates the global Overload persistent_term + Logger metadata
  use ExUnit.Case, async: false
  import Plug.Test

  alias Bonfire.Common.Overload
  alias Bonfire.UI.Common.OverloadShedPlug

  @state_key {Overload, :state}

  setup do
    on_exit(fn ->
      :persistent_term.erase(@state_key)
      Logger.metadata(caller_class: nil)
    end)

    :ok
  end

  defp force_level(level, opts \\ []) do
    :persistent_term.put(@state_key, %{
      level: level,
      mode: opts[:mode] || :enforce,
      retry_after: opts[:retry_after] || 42,
      severity: 1.0,
      sample: %{run_queue: 999}
    })
  end

  defp call(class, path \\ "/pub/shared_inbox") do
    Logger.metadata(caller_class: class)
    OverloadShedPlug.call(conn(:post, path), [])
  end

  test "at :hard, AP requests get 429 + adaptive Retry-After and the request halts" do
    force_level(:hard, retry_after: 77)

    conn = call(:ap)
    assert conn.status == 429
    assert conn.halted
    assert Plug.Conn.get_resp_header(conn, "retry-after") == ["77"]
  end

  test "guest GET page loads get the fail-whale redirect from :soft up, carrying the way home" do
    force_level(:soft, retry_after: 33)

    Logger.metadata(caller_class: :web)
    conn = OverloadShedPlug.call(conn(:get, "/post/123?x=1"), [])

    assert conn.status == 302
    assert conn.halted
    assert [location] = Plug.Conn.get_resp_header(conn, "location")
    assert location =~ "/pwa/offline.html#overloaded=33"
    assert location =~ "back=%2Fpost%2F123%3Fx%3D1"
  end

  test "logged-in browsers (session cookie present) and POSTs are NOT whale-redirected" do
    force_level(:hard)
    Logger.metadata(caller_class: :web)

    conn =
      conn(:get, "/feed")
      |> Plug.Conn.put_req_header("cookie", "_bonfire_key=abc123")
      |> OverloadShedPlug.call([])

    refute conn.halted

    # POST navigations (form submissions) are never redirected to the whale
    refute call(:web).halted
  end

  test "AP requests flow normally when calm, at :soft, and in :monitor mode" do
    refute call(:ap).halted

    force_level(:soft)
    refute call(:ap).halted

    force_level(:hard, mode: :monitor)
    refute call(:ap).halted
  end

  test "sheds are recorded via telemetry" do
    test_pid = self()

    :telemetry.attach(
      "shed-plug-test",
      [:bonfire, :overload, :shed],
      fn event, _m, metadata, _ -> send(test_pid, {event, metadata}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach("shed-plug-test") end)

    force_level(:hard)
    call(:ap)

    assert_received {[:bonfire, :overload, :shed], %{class: :federation}}
  end
end
