defmodule Bonfire.UI.Common.GuestEventGuardTest do
  @moduledoc """
  A visitor with no session reaches the event funnel through `GET /LiveHandler/<Module>/<event>`. Only the events a module declares for guests (pagination, remote interaction) run for them. Any other event is refused with a redirect to the login page, and has no effect.

  The sampled events live in bonfire_ui_social and bonfire_ui_boundaries, which are compiled into every test env of the app. The per-extension tests of each event (eg. the ones in `delegated_events_authz_test.exs`) cover the effects in more depth. The remote-interaction redirects are covered by `Bonfire.UI.Reactions.GuestRemoteInteractionTest`.
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui
  @moduletag capture_log: true

  alias Bonfire.Boundaries.Acls
  alias Bonfire.Posts

  setup do
    Process.put([:bonfire, :skip_all_boundary_checks], false)

    owner = fake_user!(fake_account!())

    {:ok, public_post} =
      Posts.publish(
        current_user: owner,
        post_attrs: %{post_content: %{html_body: "a public post for the guest guard"}},
        boundary: "public"
      )

    {:ok, private_post} =
      Posts.publish(
        current_user: owner,
        post_attrs: %{post_content: %{html_body: "a private post for the guest guard"}},
        boundary: "mentions"
      )

    {:ok,
     owner: owner,
     public_post: public_post,
     private_post: private_post,
     activity_id: id(e(public_post, :activity, nil))}
  end

  defp activity_exists?(activity_id),
    do: not is_nil(Bonfire.Common.Repo.get(Bonfire.Data.Social.Activity, activity_id))

  defp name_of(id),
    do: e(Bonfire.Common.Repo.get(Bonfire.Data.Identity.Named, id), :name, nil)

  defp assert_sent_to_login(conn) do
    assert conn.status in [301, 302], "the guest was not redirected (#{conn.status})"
    assert redirected_to(conn) =~ "/login"
  end

  describe "an event the module does not declare for guests" do
    test "Bonfire.Social.Feeds:delete is refused, and the activity stays", %{
      activity_id: activity_id
    } do
      assert activity_exists?(activity_id), "control: the activity exists to begin with"

      conn = get(build_conn(), "/LiveHandler/Bonfire.Social.Feeds/delete?id=#{activity_id}")

      assert activity_exists?(activity_id), "a guest deleted someone else's activity"
      assert_sent_to_login(conn)
    end

    test "Bonfire.Encrypt:create is refused, and no secret is stored", %{owner: owner} do
      before_count = Bonfire.Encrypt.Secret.count_secrets()

      # the request may fail while rendering its answer today, what matters is whether a secret was stored first
      conn =
        try do
          get(
            build_conn(),
            "/LiveHandler/Bonfire.Encrypt/create?" <>
              URI.encode_query(%{"id" => owner.id, "creator_key" => "guest-key"})
          )
        rescue
          _ -> nil
        end

      assert Bonfire.Encrypt.Secret.count_secrets() == before_count,
             "a guest stored a secret"

      assert conn, "the request crashed instead of being refused"
      assert_sent_to_login(conn)
    end

    test "Bonfire.Social.Objects:set_name is refused, and the name stays", %{
      owner: owner,
      public_post: post
    } do
      assert {:ok, _} =
               Bonfire.Social.Objects.set_name(post.id, "Original name", current_user: owner)

      assert name_of(post.id) == "Original name", "control: the name is set to begin with"

      conn =
        get(
          build_conn(),
          "/LiveHandler/Bonfire.Social.Objects/set_name?thread_id=#{post.id}&name=Renamed+by+a+guest"
        )

      assert name_of(post.id) == "Original name", "a guest renamed someone else's thread"
      assert_sent_to_login(conn)
    end

    test "Bonfire.Boundaries:add_object_acl is refused, and the post stays private", %{
      private_post: post
    } do
      refute Bonfire.Boundaries.can?(nil, :read, post),
             "control: the post is private to begin with"

      conn =
        get(
          build_conn(),
          "/LiveHandler/Bonfire.Boundaries/add_object_acl?id=#{Acls.get_id!(:guests_may_see_read)}&object_id=#{post.id}"
        )

      refute Bonfire.Boundaries.can?(nil, :read, post),
             "a guest made someone else's private post public"

      assert_sent_to_login(conn)
    end
  end

  describe "the UI-only events of the shared layout, on a guest's live socket" do
    import Phoenix.LiveViewTest, only: [live: 2, render_hook: 3, with_target: 2, has_element?: 2]

    test "clear-flash is pushed to the notification component without a redirect to login", %{
      public_post: post
    } do
      {:ok, view, _html} = live(build_conn(), "/discussion/#{post.id}")

      assert has_element?(view, "#notifications-1"),
             "control: the notification component is on the page"

      assert is_binary(
               view
               |> with_target("#notifications-1")
               |> render_hook("clear-flash", %{"key" => "info"})
             ),
             "the guest was redirected"
    end
  end

  describe "an event the module declares for guests" do
    # the "load more" button of a guest's feed carries the cursor and the context, and sends them as the query of a plain request
    test "Bonfire.Social.Feeds:load_more still returns the next page" do
      owner = fake_user!(fake_account!())

      posts =
        for n <- 1..5 do
          {:ok, post} =
            Posts.publish(
              current_user: owner,
              post_attrs: %{post_content: %{html_body: "guest paging post number #{n}"}},
              boundary: "public"
            )

          post
        end

      first_page = get(build_conn(), "/feed/local?test=guest_event_guard")
      assert html_response(first_page, 200) =~ "guest paging post number 5"

      button =
        first_page.resp_body
        |> Floki.parse_document!()
        |> Floki.find("button[data-id=load_more]")
        |> List.first()

      assert button, "control: the first page offers a load more button"

      # as `bonfire_basic.js` does: every `phx-value-*` attribute of the button
      {"button", attrs, _} = button
      params = for {"phx-value-" <> key, value} <- attrs, into: %{}, do: {key, value}

      assert params["after"], "control: the button carries the cursor"
      refute Enum.empty?(posts)

      conn =
        get(
          build_conn(),
          "/LiveHandler/Bonfire.Social.Feeds/load_more?" <> URI.encode_query(params)
        )

      # a request with no live socket is answered with the fallback page (the feed itself is not rendered into it), where an undeclared event is answered with a redirect to login
      assert conn.status == 200, "the guest was not served (#{conn.status})"
      assert get_resp_header(conn, "location") == []
      refute conn.resp_body =~ "You need to log in first"
    end
  end
end
