defmodule Bonfire.UI.Common.ExtensionDiffLiveTest do
  use Bonfire.UI.Common.ConnCase, async: true

  # PhoenixTest's `visit/2` doesn't follow a redirect made in a connected mount, LiveViewTest's `follow_redirect/2` does
  import Phoenix.LiveViewTest

  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)

    # outside any repo (under the app root, git would find the app's own repo), but relative since the diff joins `local` onto the root
    abs =
      Path.join(System.tmp_dir!(), "extension_diff_live_#{System.unique_integer([:positive])}")

    File.mkdir_p!(abs)
    on_exit(fn -> File.rm_rf!(abs) end)

    local =
      String.duplicate("../", length(Path.split(Bonfire.Common.Extensions.Diff.root())) - 1) <>
        String.trim_leading(abs, "/")

    {:ok, conn: conn(user: me, account: account), local: local}
  end

  test "when the diff can't be generated, the code is shown instead with the error flashed", %{
    conn: conn,
    local: local
  } do
    assert {:error, {:live_redirect, %{to: "/settings/extensions/code/bonfire_common"}}} =
             result =
             live(
               conn,
               "/settings/extensions/diff?app=bonfire_common&local=#{URI.encode_www_form(local)}"
             )

    {:ok, _view, html} = follow_redirect(result, conn)

    assert html =~ "Could not generate the diff"
    assert html =~ "not a git repository"
  end
end
