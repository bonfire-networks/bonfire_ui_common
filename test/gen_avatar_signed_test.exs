defmodule Bonfire.UI.Common.GenAvatarSignedTest do
  @moduledoc "Generated fallback avatars are only served, and cached, for the signed URLs the app itself produces, so random ids can't fill the cache."

  use Bonfire.UI.Common.ConnCase, async: true

  alias Bonfire.UI.Common.AvatarLive
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  setup do
    # the static-file cache writes each response to disk, synchronously so a test can look
    Process.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [PurgeAdapter])
    Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write], true)
    # no configured static avatar paths: the generated URL is the one under test
    Process.put([:bonfire_ui_common, AvatarLive, :generated_avatar_paths], [])

    me = fake_user!(fake_account!())
    dest = StaticGenerator.dest_path()
    on_exit(fn -> File.rm_rf!(Path.join([dest, "gen_avatar", me.id])) end)

    {:ok, dest: dest, me: me}
  end

  defp cached_file(dest, id), do: Path.join([dest, "gen_avatar", id, "index.html"])

  test "a signed URL for a real id answers the SVG and is cached", %{dest: dest, me: me} do
    src = AvatarLive.generated_avatar_src(me.id)
    assert String.starts_with?(src, "/gen_avatar/")

    conn = get(build_conn(), src)

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "svg"
    assert conn.resp_body =~ "<svg"
    assert File.exists?(Path.join([dest, String.trim_leading(src, "/"), "index.html"]))
  end

  test "a random id without a signature answers 404 and leaves no cache entry", %{dest: dest} do
    id = "random_#{System.unique_integer([:positive])}"
    on_exit(fn -> File.rm_rf!(Path.join([dest, "gen_avatar", id])) end)

    conn = get(build_conn(), "/gen_avatar/#{id}")

    assert conn.status == 404
    refute File.exists?(cached_file(dest, id))
  end

  test "a signed URL with its last character changed answers 404, and writes nothing to the cache",
       %{me: me, dest: dest} do
    signed = AvatarLive.generated_avatar_src(me.id)
    {head, last} = String.split_at(signed, -1)
    forged = head <> if(last == "a", do: "b", else: "a")

    assert get(build_conn(), forged).status == 404
    refute File.exists?(Path.join([dest, String.trim_leading(forged, "/"), "index.html"]))

    # control: the signed address still gets the image afterwards, not the earlier refusal
    assert get(build_conn(), signed).status == 200
  end
end
