defmodule Bonfire.UI.Common.EmbedWidgetCacheTest do
  @moduledoc """
  Widget embeds are cached for guests when the instance turns it on (`CACHE_WIDGET_EMBEDS`), tagged with the widget so its saved copies, one per query string, are purged together.

  Outside prod `CacheControlPlug` never lets a response be cached (unless `STATIC_CACHE_DEV` was set at compile time), so these check what's left to see: the tag, the plug's answer to a signed-in request, and the purge of copies saved on disk.
  """
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  @path "/embed/widget/custom_hello"

  # where `MaybeStaticGeneratorPlug` saves the copy of `@path` with this query string
  defp copy_file(qs) do
    hash = :crypto.hash(:sha256, qs) |> Base.encode16(case: :lower) |> binary_part(0, 8)

    Path.join([
      StaticGenerator.dest_path(),
      String.trim_leading(@path, "/"),
      "_qs_" <> hash,
      "index.html"
    ])
  end

  setup do
    Process.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [PurgeAdapter])

    Process.put([:bonfire_ui_common, Bonfire.UI.Common.Widgets, :custom], %{
      hello: %{title: "Embedded hello", text: "Hello from **the instance**"}
    })

    on_exit(fn ->
      File.rm_rf!(Path.join(StaticGenerator.dest_path(), String.trim_leading(@path, "/")))
    end)

    :ok
  end

  defp cache_on,
    do: Process.put([:bonfire_ui_common, Bonfire.UI.Common.EmbedWidgetController, :cache], true)

  test "off unless the instance turns it on: the embed isn't tagged for caching" do
    conn = get(conn(), @path <> "?theme=dark")

    assert conn.status == 200
    assert get_resp_header(conn, "surrogate-key") == []
  end

  test "turned on, a guest's embed is tagged with the widget, so its copies can be purged together" do
    cache_on()

    conn = get(conn(), @path <> "?theme=dark")

    assert conn.status == 200
    assert get_resp_header(conn, "surrogate-key") == ["embed/widget/custom_hello"]
  end

  test "turned on, a signed-in request is never kept by a shared cache" do
    cache_on()
    account = fake_account!()

    conn = conn(user: fake_user!(account), account: account) |> get(@path <> "?theme=dark")

    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  # a copy of a widget's embed saved on disk, as the static cache saves one per query string
  defp save_embed_copy(id) do
    file =
      Path.join([
        StaticGenerator.dest_path(),
        Bonfire.UI.Common.Widgets.embed_tag(id),
        "_qs_saved",
        "index.html"
      ])

    File.mkdir_p!(Path.dirname(file))
    File.write!(file, "a saved copy")
    on_exit(fn -> File.rm_rf!(Path.dirname(Path.dirname(file))) end)
    file
  end

  describe "a widget's refresh button" do
    setup do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles]
      )

      :ok
    end

    test "purges its embed when a moderator presses it" do
      account = fake_account!()
      admin = fake_admin!(account)
      copy = save_embed_copy(:suggested_profiles)

      {:ok, view, _html} = live(conn(user: admin, account: account), "/dashboard")

      view
      |> element("[data-widget-id=suggested_profiles] [data-role=widget-reset]")
      |> render_click()

      refute File.exists?(copy)
    end

    test "doesn't purge it for a member, who has no button and whose own push is refused" do
      account = fake_account!()
      copy = save_embed_copy(:suggested_profiles)

      {:ok, view, _html} = live(conn(user: fake_user!(account), account: account), "/dashboard")

      refute has_element?(view, "[data-widget-id=suggested_profiles] [data-role=widget-reset]")

      render_hook(view, "Bonfire.UI.Common.WidgetBlockLive:bust_embed", %{
        "event" => "Bonfire.UI.Social.WidgetSuggestedProfilesLive:reset_suggested_profiles"
      })

      assert File.exists?(copy)
    end
  end

  test "purging a widget's embed removes the copies of every query string" do
    for qs <- ["theme=dark", "theme=light"] do
      File.mkdir_p!(Path.dirname(copy_file(qs)))
      File.write!(copy_file(qs), "a saved copy")
    end

    Bonfire.UI.Common.Widgets.bust_embed(:custom_hello)

    refute File.exists?(copy_file("theme=dark"))
    refute File.exists?(copy_file("theme=light"))
  end
end
