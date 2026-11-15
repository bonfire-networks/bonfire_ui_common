defmodule Bonfire.UI.Common.RefusalUxTest do
  @moduledoc """
  A visitor with no session who is refused is sent to the login page. Someone who is signed in and refused (with `Bonfire.Fail.Auth` or `{:error, :not_permitted}`) stays on the page they are on, and is told they do not have permission: logging in again would not change the answer.
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui
  @moduletag capture_log: true

  setup do
    account = fake_account!()
    {:ok, account: account, me: fake_user!(account)}
  end

  describe "a handler that raises Bonfire.Fail.Auth (move_away with a wrong password)" do
    @params %{"user" => "someone@elsewhere.local", "password" => "not my password"}

    test "a guest is sent to the login page" do
      conn =
        get(
          build_conn(),
          "/LiveHandler/Bonfire.Social.Graph.Aliases/move_away?" <> URI.encode_query(@params)
        )

      assert conn.status in [301, 302]
      assert redirected_to(conn) =~ "/login"
    end

    # a wrong password is not a missing permission, so this only checks they stay where they are
    test "someone signed in stays on the page", %{
      account: account,
      me: me
    } do
      {:ok, view, _html} = live(conn(user: me, account: account), "/feed/local")

      result = render_hook(view, "Bonfire.Social.Graph.Aliases:move_away", @params)

      refute match?(
               {:error, {kind, %{to: "/login" <> _}}} when kind in [:redirect, :live_redirect],
               result
             ),
             "someone signed in was sent to the login page"
    end
  end

  describe "an event the sender has no permission for (add_object_acl on someone else's post)" do
    setup do
      owner = fake_user!(fake_account!())

      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: owner,
          post_attrs: %{post_content: %{html_body: "not for guests"}},
          boundary: "mentions"
        )

      {:ok, post: post}
    end

    test "someone signed in stays on the page, is told they do not have permission, and nothing changes",
         %{account: account, me: me, post: post} do
      refute Bonfire.Boundaries.can?(nil, :read, post),
             "control: the post is private to begin with"

      {:ok, view, _html} = live(conn(user: me, account: account), "/feed/local")

      result =
        render_hook(view, "Bonfire.Boundaries:add_object_acl", %{
          "id" => Bonfire.Boundaries.Acls.get_id!(:guests_may_see_read),
          "object_id" => post.id
        })

      refute match?(
               {:error, {kind, %{to: "/login" <> _}}} when kind in [:redirect, :live_redirect],
               result
             ),
             "someone signed in was sent to the login page"

      refute Bonfire.Boundaries.can?(nil, :read, post), "the post was made public"
      assert result =~ "do not have permission"
    end
  end
end
